
# The base class for REST client exceptions.
class RestError(Exception):
    code = None
    message = 'An unspecified error occurred'

    def __init__(self, code=None, message=None):
        self.code = code
        self.message = message
    

# RestClientError indicates that a problem occurred inside the client code, 
# either while trying to send a request to service or while trying to parse a response from it. 
# An RestClientError is generally more severe than an RestServiceError, 
# and indicates a major problem that is preventing the client from making service calls to the services. 
# For example, if no network connection is available when you try to call an operation.    
class RestClientError(RestError):
    url = None

    def __init__(self, code=None, message=None, url=None):
        super().__init__(code=code, message=message)
        self.url = url

    def __str__(self):
        return "REST client error: code={code}, message='{message}', url='{url}'" \
               .format(code=self.code, message=self.message, url=self.url)

# RestServiceError represent an error response from a REST service. 
class RestServiceError(RestError):
    details = None
    
    def __init__(self, code=None, message=None, details=None):
        super().__init__(code=code, message=message)
        self.details = details

    def __str__(self):
        return "REST service error: code={code}, message='{message}', details={details}" \
               .format(code=self.code, message=self.message, details=self.details)