# Copyright 2026 Esri
#
# Licensed under the Apache License Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Run Windows infrastructure setup on an EC2 instance via SSM
# Arguments:
#   instance - EC2 instance ID
#   role - Role of the instance
#   bucket - S3 bucket for command output
#   prefix - S3 key prefix for command output
#   script - PowerShell script to execute

import base64
import gzip
import json
import os
import re
import sys
from contextlib import closing
from time import monotonic, sleep

import boto3
from botocore.exceptions import BotoCoreError, ClientError


TERMINAL = {"Success", "Failed", "Cancelled", "TimedOut", "Undeliverable", "Terminated"}


def emit(label, stream, line):
    # Prefix every physical line; guest output is not a CI workflow command.
    for part in line.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
        safe = part.replace(chr(27), r"\x1b")
        print(f"{label} [{stream}] {safe}",
              file=sys.stderr if stream == "stderr" else sys.stdout, flush=True)


def replay(s3, bucket, prefix, label, invocation, step_name=None, *, expected_streams=()):
    seen = set()
    streams = {
        "stdout": "StandardOutputContent",
        "stderr": "StandardErrorContent",
    }
    deadline = monotonic() + 30
    # SSM's agent intentionally omits empty files from S3.
    expected = set(expected_streams) | {name for name, content in streams.items() if invocation.get(content)}
    while True:
        for page in s3.get_paginator("list_objects_v2").paginate(Bucket=bucket, Prefix=prefix):
            for entry in page.get("Contents", []):
                key = entry["Key"]
                stream = key.rsplit("/", 1)[-1]
                if stream not in streams or key in seen:
                    continue
                if step_name:
                    # The agent may nest the document step under the plugin type.
                    directories = key[len(prefix):].split("/")[:-1]
                    if not any(part.replace(":", "") == step_name.replace(":", "") for part in directories):
                        continue
                # StreamingBody.__enter__ returns the raw response, which lacks iter_lines().
                with closing(s3.get_object(Bucket=bucket, Key=key)["Body"]) as body:
                    for line in body.iter_lines():
                        emit(label, stream, line.decode("utf-8", "replace"))
                seen.add(key)
        missing = expected - {key.rsplit("/", 1)[-1] for key in seen}
        if not missing or monotonic() >= deadline:
            break
        sleep(3)
    for name in sorted(missing):
        print(f"{label} [{name}] Expected output was not available in S3.",
              file=sys.stderr, flush=True)
    return not missing


def discover(ec2, ssm, tags):
    filters = [{"Name": tag["Key"], "Values": tag["Values"]} for tag in tags]
    filters.append({"Name": "instance-state-name", "Values": ["pending", "running"]})
    online_deadline = monotonic() + 600
    while True:
        instances = {
            node["InstanceId"]: node
            for page in ec2.get_paginator("describe_instances").paginate(Filters=filters)
            for reservation in page["Reservations"] for node in reservation["Instances"]
        }
        for instance, node in instances.items():
            if node.get("Platform") != "windows" or not re.fullmatch(r"i-[0-9a-f]+", instance):
                raise ValueError(f"Tag match {instance} is not an eligible Windows EC2 instance; no command sent.")
        online = {
            node["InstanceId"]
            for page in ssm.get_paginator("describe_instance_information").paginate(Filters=tags)
            for node in page["InstanceInformationList"]
            if node["PingStatus"] == "Online" and node.get("PlatformType") == "Windows"
        } if instances else set()
        not_ready = {instance for instance, node in instances.items()
                     if instance not in online or node["State"]["Name"] != "running"}
        if instances and not not_ready:
            return instances
        remaining = online_deadline - monotonic()
        if remaining <= 0:
            detail = f"Targets not ready: {', '.join(sorted(not_ready))}." if instances else "No eligible EC2 tag matches."
            raise ValueError(f"{detail} No command sent.")
        sleep(min(10, remaining))


def validate_volumes(ec2, instances, size, snapshot):
    targets = {}
    for instance, node in sorted(instances.items()):
        disks = [mapping.get("Ebs", {}) for mapping in node.get("BlockDeviceMappings", [])
                 if mapping["DeviceName"] == "/dev/sdf"]
        volume = disks[0].get("VolumeId", "") if len(disks) == 1 else ""
        if not re.fullmatch(r"vol-[0-9a-f]+", volume) or disks[0].get("Status") != "attached":
            raise ValueError(f"{instance} does not have exactly one attached /dev/sdf EBS volume; no command sent.")
        targets[instance] = volume
    if len(set(targets.values())) != len(targets):
        raise ValueError("Multiple targets refer to the same data volume; no command sent.")
    volumes = {
        volume["VolumeId"]: volume
        for page in ec2.get_paginator("describe_volumes").paginate(
            Filters=[{"Name": "volume-id", "Values": list(targets.values())}])
        for volume in page["Volumes"]
    }
    for instance, volume_id in targets.items():
        volume = volumes.get(volume_id, {})
        attachments = volume.get("Attachments", [])
        if (volume.get("State") != "in-use" or volume.get("Size", 0) < size
                or len(attachments) != 1 or attachments[0].get("InstanceId") != instance
                or attachments[0].get("Device") != "/dev/sdf" or attachments[0].get("State") != "attached"):
            raise ValueError(f"{instance} data volume {volume_id} has an invalid attachment or capacity; no command sent.")
        if snapshot and volume.get("SnapshotId") != snapshot:
            raise ValueError(f"{instance} data volume {volume_id} is not from snapshot {snapshot}; no command sent.")
    return targets


def terminal(invocation):
    return invocation["Status"] in TERMINAL or invocation.get("StatusDetails") in {
        "Delivery Timed Out", "Execution Timed Out", "Undeliverable", "Terminated",
        "Invalid Platform", "Access Denied",
    }


def run(ec2, ssm, s3, enterprise, deployment, role, bucket, script, size, snapshot, replay_logs):
    tags = [{"Key": f"tag:{key}", "Values": [value]} for key, value in (
        ("ArcGISEnterpriseID", enterprise), ("ArcGISDeploymentID", deployment), ("ArcGISMachineRole", role),
    )]
    targets = validate_volumes(ec2, discover(ec2, ssm, tags), size, snapshot)
    marker = "__ARCGIS_VALIDATED_TARGETS__"
    if script.count(marker) != 1:
        raise ValueError("PowerShell payload must contain one validated target placeholder; no command sent.")
    script = script.replace(marker, base64.b64encode(json.dumps(targets, separators=(",", ":")).encode()).decode())
    if len(script.encode("utf-8")) > 64000:
        raise ValueError("PowerShell payload exceeds 64,000 bytes with the validated targets; no command sent.")
    prefix = f"{deployment}/disk-preparation/{role}"
    sent = ssm.send_command(
        Targets=tags, DocumentName="AWS-RunPowerShellScript", MaxErrors="100%",
        TimeoutSeconds=600, Parameters={"commands": [script], "executionTimeout": ["3600"]},
        OutputS3BucketName=bucket, OutputS3KeyPrefix=prefix,
    )["Command"]
    command = sent["CommandId"]
    label = f"[AWS {role} {command}]"
    print(f"{label} Preparing Windows infrastructure on {len(targets)} validated instances", flush=True)
    observed = {}
    deadline = monotonic() + 4260
    ok = True
    try:
        paginator = ssm.get_paginator("list_command_invocations")
        while True:
            for page in paginator.paginate(CommandId=command, Details=True):
                for item in page["CommandInvocations"]:
                    instance = item["InstanceId"]
                    if instance not in observed or terminal(item) or not terminal(observed[instance]):
                        observed[instance] = item
            if targets.keys() <= observed.keys() and all(map(terminal, observed.values())):
                break
            remaining = deadline - monotonic()
            if remaining <= 0:
                print(f"{label} Wait timed out; check SSM before retrying.", file=sys.stderr, flush=True)
                ok = False
                break
            sleep(min(5, remaining))
    except (BotoCoreError, ClientError) as exc:
        print(f"{label} Could not poll invocations ({type(exc).__name__}); check SSM before retrying.",
              file=sys.stderr, flush=True)
        ok = False
    missing = targets.keys() - observed.keys()
    unexpected = observed.keys() - targets.keys()
    if missing or unexpected or sent.get("TargetCount", 0) > len(targets):
        print(f"{label} Target set changed. Missing: {', '.join(sorted(missing)) or 'none'}; "
              f"unexpected: {', '.join(sorted(unexpected)) or 'none visible'}.",
              file=sys.stderr, flush=True)
        ok = False
    for instance, invocation in sorted(observed.items()):
        instance_label = f"[AWS {role} {instance} {command}]"
        status = invocation.get("StatusDetails") or invocation["Status"]
        plugins = invocation.get("CommandPlugins", [])
        plugin = plugins[0] if len(plugins) == 1 else {}
        code = plugin.get("ResponseCode", -1)
        print(f"{instance_label} SSM status: {status} (exit {code})", flush=True)
        if not (invocation["Status"] == status == plugin.get("Status") == "Success" and code == 0):
            ok = False
        if replay_logs:
            stdout, _, stderr = (plugin.get("Output") or "").replace("\r\n", "\n").partition(
                "\n----------ERROR-------\n")
            try:
                collected = replay(s3, bucket, f"{prefix}/{command}/{instance}/", instance_label,
                                   {"StandardOutputContent": stdout, "StandardErrorContent": stderr})
                ok = ok and collected
            except (BotoCoreError, ClientError, OSError) as exc:
                print(f"{instance_label} Could not retrieve stdout/stderr ({type(exc).__name__}).",
                      file=sys.stderr, flush=True)
                ok = False
    return 0 if ok else 1


if __name__ == "__main__":
    try:
        snapshot = os.environ["ARCGIS_DATA_SNAPSHOT_ID"]
        sys.exit(run(boto3.client("ec2"), boto3.client("ssm"), boto3.client("s3"),
                     os.environ["ARCGIS_ENTERPRISE_ID"], os.environ["ARCGIS_DEPLOYMENT_ID"],
                     os.environ["ARCGIS_ROLE"], os.environ["ARCGIS_LOG_BUCKET"],
                     gzip.decompress(base64.b64decode(os.environ["ARCGIS_POWERSHELL"])).decode("utf-8"),
                     int(os.environ["ARCGIS_DATA_DISK_SIZE"]),
                     None if snapshot == "-" else snapshot,
                     os.environ["ARCGIS_REPLAY_LOGS"] == "true"))
    except (BotoCoreError, ClientError, KeyError, ValueError, OSError, EOFError) as exc:
        sys.exit(f"AWS Windows infrastructure runner failed: {exc}")
