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

resource "azurerm_web_application_firewall_policy" "arcgis_enterprise" {
  name                = "${var.site_id}-${var.deployment_id}-waf"
  resource_group_name = azurerm_resource_group.deployment_rg.name
  location            = azurerm_resource_group.deployment_rg.location

  policy_settings {
    enabled                     = true
    mode                        = var.waf_mode == "detect" ? "Detection" : "Protection"
    request_body_check          = true
    file_upload_limit_in_mb     = 100
    max_request_body_size_in_kb = 128
  }

  managed_rules {
    exclusion {
      match_variable          = "RequestArgNames"
      selector_match_operator = "Equals"
      selector                = "token"
    }

    exclusion {
      match_variable          = "RequestCookieNames"
      selector_match_operator = "Equals"
      selector                = "esri_auth"
    }

    exclusion {
      match_variable          = "RequestCookieNames"
      selector_match_operator = "Equals"
      selector                = "esri_aopc"
    }

    managed_rule_set {
      type    = "Microsoft_DefaultRuleSet"
      version = "2.1"

      rule_group_override {
        rule_group_name = "PROTOCOL-ENFORCEMENT"

        rule {
          id = "920100" # Invalid HTTP Request Line
        }

        rule {
          id = "920230" # Multiple URL Encoding Detected
        }

        rule {
          id = "920271" # Invalid character in request (non printable characters)
        }

        rule {
          id = "920300" # Request Missing an Accept Header
        }

        rule {
          id = "920320" # Missing User Agent Header
        }

        rule {
          id = "920340" # Request Containing Content, but Missing Content-Type header
        }

        rule {
          id = "920341" # Request containing content requires Content-Type header
        }

        rule {
          id = "920350" # Host header is a numeric IP address
        }

        rule {
          id = "920420" # Request content type is not allowed by policy
        }

        rule {
          id = "920440" # URL file extension is restricted by policy
        }

        rule {
          id = "920470" # Illegal Content-Type header
        }

        rule {
          id = "920480" # Restrict charset parameter within the content-type header
        }
      }

      rule_group_override {
        rule_group_name = "PROTOCOL-ATTACK"

        rule {
          id = "921150" # HTTP Header Injection Attack via payload (CR/LF detected)
        }

        rule {
          id = "921151" # HTTP Header Injection Attack via payload (CR/LF detected)
        }
      }

      rule_group_override {
        rule_group_name = "LFI"

        rule {
          id = "930100" # Path Traversal Attack (/../) 
        }

        rule {
          id = "930110" # Path Traversal Attack (/../) 
        }
      }

      rule_group_override {
        rule_group_name = "RFI"

        rule {
          id = "931100" # Possible Remote File Inclusion (RFI) Attack: URL Parameter using IP Address
        }

        rule {
          id = "931110" # Possible Remote File Inclusion (RFI) Attack: URL Payload
        }

        rule {
          id = "931120" # Possible Remote File Inclusion (RFI) Attack: URL Payload Used w/Trailing Question Mark Character (?) 
        }

        rule {
          id = "931130" # Possible Remote File Inclusion (RFI) Attack: Off-Domain Reference/Link
        }
      }

      rule_group_override {
        rule_group_name = "RCE"

        rule {
          id = "932100" # Remote Command Execution: Unix Command Injection
        }

        rule {
          id = "932105" # Remote Command Execution: Unix Command Injection
        }

        rule {
          id = "932110" # Remote Command Execution: Windows Command Injection
        }

        rule {
          id = "932115" # Remote Command Execution: Windows Command Injection
        }

        rule {
          id = "932120" # Remote Command Execution: Windows PowerShell Command Found
        }

        rule {
          id = "932150" # Remote Command Execution: Direct Unix Command Execution 
        }

        rule {
          id = "932160" # Remote Command Execution: Unix Shell Code Found
        }
      }

      rule_group_override {
        rule_group_name = "PHP"

        rule {
          id = "933180" # PHP Injection Attack: Variable Function Call Found
        }
      }

      rule_group_override {
        rule_group_name = "XSS"

        rule {
          id = "941100" # XSS Attack Detected via libinjection
        }

        rule {
          id = "941110" # XSS Filter - Category 1: Script Tag Vector
        }

        rule {
          id = "941140" # XSS Filter - Category 4: Javascript URI Vector
        }

        rule {
          id = "941150" # XSS Filter - Category 5: Disallowed HTML Attributes
        }

        rule {
          id = "941160" # NoScript XSS InjectionChecker: HTML Injection
        }

        rule {
          id = "941200" # XSS using VML frames
        }

        rule {
          id = "941310" # US-ASCII Malformed Encoding XSS Filter - Attack Detected.
        }

        rule {
          id = "941320" # Possible XSS Attack Detected - HTML Tag Handler
        }

        rule {
          id = "941330" # IE XSS Filters - Attack Detected. 
        }

        rule {
          id = "941340" # IE XSS Filters - Attack Detected.
        }

        rule {
          id = "941350" # UTF-7 Encoding IE XSS - Attack Detected
        }
      }

      rule_group_override {
        rule_group_name = "SQLI"
        rule {
          id = "942100" # SQL Injection Attack Detected via libinjection
        }

        rule {
          id = "942110" # SQL Injection Attack: Common Injection Testing Detected
        }

        rule {
          id = "942120" # SQL Injection Attack: SQL Operator Detected
        }

        rule {
          id = "942130" # SQL Injection Attack: SQL Tautology Detected.
        }

        rule {
          id = "942150" # SQL Injection Attack
        }

        rule {
          id = "942180" # Detects basic SQL authentication bypass attempts 1/3
        }

        rule {
          id = "942190" # Detects MSSQL code execution and information gathering attempts
        }

        rule {
          id = "942200" # Detects MySQL comment-/space-obfuscated injections and backtick termination
        }

        rule {
          id = "942210" # Detects chained SQL injection attempts 1/2
        }

        rule {
          id = "942230" # Detects conditional SQL injection attempts
        }

        rule {
          id = "942260" # Detects basic SQL authentication bypass attempts 2/3
        }

        rule {
          id = "942300" # Detects MySQL comments, conditions and ch(a)r injections
        }

        rule {
          id = "942310" # Detects chained SQL injection attempts 2/2 
        }

        rule {
          id = "942330" # Detects classic SQL injection probings 1/2
        }

        rule {
          id = "942340" # Detects basic SQL authentication bypass attempts 3/3
        }

        rule {
          id = "942370" # Detects classic SQL injection probings 2/2
        }

        rule {
          id = "942380" # SQL Injection Attack
        }

        rule {
          id = "942390" # SQL Injection Attack
        }

        rule {
          id = "942410" # SQL Injection Attack
        }

        rule {
          id = "942430" # Restricted SQL Character Anomaly Detection (args): # of special characters exceeded (12)
        }

        rule {
          id = "942440" # SQL Comment Sequence Detected.
        }

        rule {
          id = "942450" # SQL Hex Encoding Identified
        }

        # rule {
        #   id = "942460" # Meta-Character Anomaly Detection Alert - Repetitive Non-Word Characters
        # }
      }

      rule_group_override {
        rule_group_name = "JAVA"
        rule {
          id = "944100" # Remote Command Execution: Apache Struts, Oracle WebLogic
        }

        rule {
          id = "944110" # Detects potential payload execution
        }

        rule {
          id = "944130" # Suspicious Java classes
        }

        rule {
          id = "944250" # Remote Command Execution: Suspicious Java method detected
        }
      }
    }

    managed_rule_set {
      type = "Microsoft_BotManagerRuleSet"
      version = "1.1" 
    }

    # managed_rule_set {
    #   type    = "OWASP"
    #   version = "3.2"

    #   rule_group_override {
    #     rule_group_name = "REQUEST-913-SCANNER-DETECTION"

    #     rule {
    #       id = "913101" # Found User-Agent associated with scripting/generic HTTP client
    #     }
    #   }

    #   rule_group_override {
    #     rule_group_name = "REQUEST-920-PROTOCOL-ENFORCEMENT"

    #     rule {
    #       id = "920100" # Invalid HTTP Request Line
    #     }

    #     rule {
    #       id = "920230" # Multiple URL Encoding Detected
    #     }

    #     rule {
    #       id = "920271" # Invalid character in request (non printable characters)
    #     }

    #     rule {
    #       id = "920300" # Request Missing an Accept Header
    #     }

    #     rule {
    #       id = "920320" # Missing User Agent Header
    #     }

    #     rule {
    #       id = "920340" # Request Containing Content, but Missing Content-Type header
    #     }

    #     rule {
    #       id = "920341" # Request containing content requires Content-Type header
    #     }

    #     rule {
    #       id = "920350" # Host header is a numeric IP address
    #     }

    #     rule {
    #       id = "920420" # Request content type is not allowed by policy
    #     }

    #     rule {
    #       id = "920440" # URL file extension is restricted by policy
    #     }

    #     rule {
    #       id = "920470" # Illegal Content-Type header
    #     }

    #     rule {
    #       id = "920480" # Restrict charset parameter within the content-type header
    #     }
    #   }

    #   rule_group_override {
    #     rule_group_name = "REQUEST-921-PROTOCOL-ATTACK"

    #     rule {
    #       id = "921150" # HTTP Header Injection Attack via payload (CR/LF detected)
    #     }

    #     rule {
    #       id = "921151" # HTTP Header Injection Attack via payload (CR/LF detected)
    #     }
    #   }

    #   rule_group_override {
    #     rule_group_name = "REQUEST-930-APPLICATION-ATTACK-LFI"

    #     rule {
    #       id = "930100" # Path Traversal Attack (/../) 
    #     }

    #     rule {
    #       id = "930110" # Path Traversal Attack (/../) 
    #     }
    #   }

    #   rule_group_override {
    #     rule_group_name = "REQUEST-931-APPLICATION-ATTACK-RFI"

    #     rule {
    #       id = "931100" # Possible Remote File Inclusion (RFI) Attack: URL Parameter using IP Address
    #     }

    #     rule {
    #       id = "931110" # Possible Remote File Inclusion (RFI) Attack: URL Payload
    #     }

    #     rule {
    #       id = "931120" # Possible Remote File Inclusion (RFI) Attack: URL Payload Used w/Trailing Question Mark Character (?) 
    #     }

    #     rule {
    #       id = "931130" # Possible Remote File Inclusion (RFI) Attack: Off-Domain Reference/Link
    #     }
    #   }

    #   rule_group_override {
    #     rule_group_name = "REQUEST-932-APPLICATION-ATTACK-RCE"

    #     rule {
    #       id = "932100" # Remote Command Execution: Unix Command Injection
    #     }

    #     rule {
    #       id = "932105" # Remote Command Execution: Unix Command Injection
    #     }

    #     rule {
    #       id = "932110" # Remote Command Execution: Windows Command Injection
    #     }

    #     rule {
    #       id = "932115" # Remote Command Execution: Windows Command Injection
    #     }

    #     rule {
    #       id = "932120" # Remote Command Execution: Windows PowerShell Command Found
    #     }

    #     rule {
    #       id = "932150" # Remote Command Execution: Direct Unix Command Execution 
    #     }

    #     rule {
    #       id = "932160" # Remote Command Execution: Unix Shell Code Found
    #     }
    #   }

    #   rule_group_override {
    #     rule_group_name = "REQUEST-933-APPLICATION-ATTACK-PHP"

    #     rule {
    #       id = "933180" # PHP Injection Attack: Variable Function Call Found
    #     }
    #   }

    #   rule_group_override {
    #     rule_group_name = "REQUEST-941-APPLICATION-ATTACK-XSS"

    #     rule {
    #       id = "941100" # XSS Attack Detected via libinjection
    #     }

    #     rule {
    #       id = "941110" # XSS Filter - Category 1: Script Tag Vector
    #     }

    #     rule {
    #       id = "941140" # XSS Filter - Category 4: Javascript URI Vector
    #     }

    #     rule {
    #       id = "941150" # XSS Filter - Category 5: Disallowed HTML Attributes
    #     }

    #     rule {
    #       id = "941160" # NoScript XSS InjectionChecker: HTML Injection
    #     }

    #     rule {
    #       id = "941200" # XSS using VML frames
    #     }

    #     rule {
    #       id = "941310" # US-ASCII Malformed Encoding XSS Filter - Attack Detected.
    #     }

    #     rule {
    #       id = "941320" # Possible XSS Attack Detected - HTML Tag Handler
    #     }

    #     rule {
    #       id = "941330" # IE XSS Filters - Attack Detected. 
    #     }

    #     rule {
    #       id = "941340" # IE XSS Filters - Attack Detected.
    #     }

    #     rule {
    #       id = "941350" # UTF-7 Encoding IE XSS - Attack Detected
    #     }
    #   }

    #   rule_group_override {
    #     rule_group_name = "REQUEST-942-APPLICATION-ATTACK-SQLI"
    #     rule {
    #       id = "942100" # SQL Injection Attack Detected via libinjection
    #     }

    #     rule {
    #       id = "942110" # SQL Injection Attack: Common Injection Testing Detected
    #     }

    #     rule {
    #       id = "942120" # SQL Injection Attack: SQL Operator Detected
    #     }

    #     rule {
    #       id = "942130" # SQL Injection Attack: SQL Tautology Detected.
    #     }

    #     rule {
    #       id = "942150" # SQL Injection Attack
    #     }

    #     rule {
    #       id = "942180" # Detects basic SQL authentication bypass attempts 1/3
    #     }

    #     rule {
    #       id = "942190" # Detects MSSQL code execution and information gathering attempts
    #     }

    #     rule {
    #       id = "942200" # Detects MySQL comment-/space-obfuscated injections and backtick termination
    #     }

    #     rule {
    #       id = "942210" # Detects chained SQL injection attempts 1/2
    #     }

    #     rule {
    #       id = "942230" # Detects conditional SQL injection attempts
    #     }

    #     rule {
    #       id = "942260" # Detects basic SQL authentication bypass attempts 2/3
    #     }

    #     rule {
    #       id = "942300" # Detects MySQL comments, conditions and ch(a)r injections
    #     }

    #     rule {
    #       id = "942310" # Detects chained SQL injection attempts 2/2 
    #     }

    #     rule {
    #       id = "942330" # Detects classic SQL injection probings 1/2
    #     }

    #     rule {
    #       id = "942340" # Detects basic SQL authentication bypass attempts 3/3
    #     }

    #     rule {
    #       id = "942370" # Detects classic SQL injection probings 2/2
    #     }

    #     rule {
    #       id = "942380" # SQL Injection Attack
    #     }

    #     rule {
    #       id = "942390" # SQL Injection Attack
    #     }

    #     rule {
    #       id = "942410" # SQL Injection Attack
    #     }

    #     rule {
    #       id = "942430" # Restricted SQL Character Anomaly Detection (args): # of special characters exceeded (12)
    #     }

    #     rule {
    #       id = "942440" # SQL Comment Sequence Detected.
    #     }

    #     rule {
    #       id = "942450" # SQL Hex Encoding Identified
    #     }

    #     rule {
    #       id = "942460" # Meta-Character Anomaly Detection Alert - Repetitive Non-Word Characters
    #     }
    #   }

    #   rule_group_override {
    #     rule_group_name = "REQUEST-944-APPLICATION-ATTACK-JAVA"
    #     rule {
    #       id = "944100" # Remote Command Execution: Apache Struts, Oracle WebLogic
    #     }

    #     rule {
    #       id = "944110" # Detects potential payload execution
    #     }

    #     rule {
    #       id = "944130" # Suspicious Java classes
    #     }

    #     rule {
    #       id = "944250" # Remote Command Execution: Suspicious Java method detected
    #     }
    #   }
    # }
  }
}
