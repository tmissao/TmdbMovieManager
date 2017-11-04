import Foundation

// MARK: - TMDBClient: NSObject

class TMDBClient : NSObject {
  
  // MARK: Properties
  
  // shared session
  var session = URLSession.shared
  
  // configuration object
  var config = TMDBConfig()
  
  // authentication state
  var requestToken: String? = nil
  var sessionID : String? = nil
  var userID : Int? = nil
  
  // MARK: Initializers
  
  override init() {
    super.init()
  }
  
  // MARK: GET
  
  
  /// Executes a GET request on network
  ///
  /// - Parameters:
  ///   - method: TMDB method to be executed
  ///   - parameters: Query params to be add on the URL
  ///   - completionHandlerForGET: Callback to executed after request is performed
  /// - Returns: URLSessionDataTask
  func taskForGETMethod(_ method: String, parameters: [String:AnyObject], completionHandlerForGET: @escaping (_ result: AnyObject?, _ error: NSError?) -> Void) -> URLSessionDataTask {
    
    var parametersWithApiKey = parameters
    parametersWithApiKey[ParameterKeys.ApiKey] = Constants.ApiKey as AnyObject?
    let request = NSMutableURLRequest(url: tmdbURLFromParameters(parametersWithApiKey, withPathExtension: method))
    let task = session.dataTask(with: request as URLRequest) { (data, response, error) in
      
      func sendError(_ error: String) {
        print(error)
        let userInfo = [NSLocalizedDescriptionKey : error]
        completionHandlerForGET(nil, NSError(domain: "taskForGETMethod", code: 1, userInfo: userInfo))
      }
      
      guard (error == nil) else {
        sendError("There was an error with your request: \(error!)")
        return
      }
      
      guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 200 && statusCode <= 299 else {
        sendError("Your request returned a status code other than 2xx!")
        return
      }
      
      guard let data = data else {
        sendError("No data was returned by the request!")
        return
      }
      
      self.convertDataWithCompletionHandler(data, completionHandlerForConvertData: completionHandlerForGET)
    }
    
    task.resume()
    
    return task
  }
  
  // MARK: POST
  
  
  /// Executes a POST request on network
  ///
  /// - Parameters:
  ///   - method: TMDB method to be executed
  ///   - parameters: Query params to be add on the URL
  ///   - jsonBody: Json to be sent on request
  ///   - completionHandlerForPOST: Callback to executed after request is performed
  /// - Returns: URLSessionDataTask
  func taskForPOSTMethod(_ method: String, parameters: [String:AnyObject], jsonBody: String, completionHandlerForPOST: @escaping (_ result: AnyObject?, _ error: NSError?) -> Void) -> URLSessionDataTask {
    
    var parametersWithApiKey = parameters
    parametersWithApiKey[ParameterKeys.ApiKey] = Constants.ApiKey as AnyObject?
    
    let request = NSMutableURLRequest(url: tmdbURLFromParameters(parametersWithApiKey, withPathExtension: method))
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "Accept")
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = jsonBody.data(using: String.Encoding.utf8)
    
    let task = session.dataTask(with: request as URLRequest) { (data, response, error) in
      
      func sendError(_ error: String) {
        print(error)
        let userInfo = [NSLocalizedDescriptionKey : error]
        completionHandlerForPOST(nil, NSError(domain: "taskForGETMethod", code: 1, userInfo: userInfo))
      }
      
      guard (error == nil) else {
        sendError("There was an error with your request: \(error!)")
        return
      }
      
      guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 200 && statusCode <= 299 else {
        sendError("Your request returned a status code other than 2xx!")
        return
      }
      
      guard let data = data else {
        sendError("No data was returned by the request!")
        return
      }
      
      self.convertDataWithCompletionHandler(data, completionHandlerForConvertData: completionHandlerForPOST)
    }
    
    task.resume()
    
    return task
  }
  
  // MARK: GET Image
  
  func taskForGETImage(_ size: String, filePath: String, completionHandlerForImage: @escaping (_ imageData: Data?, _ error: NSError?) -> Void) -> URLSessionTask {
    
    
    let baseURL = URL(string: config.baseImageURLString)!
    let url = baseURL.appendingPathComponent(size).appendingPathComponent(filePath)
    let request = URLRequest(url: url)
    
    let task = session.dataTask(with: request) { (data, response, error) in
      
      func sendError(_ error: String) {
        print(error)
        let userInfo = [NSLocalizedDescriptionKey : error]
        completionHandlerForImage(nil, NSError(domain: "taskForGETMethod", code: 1, userInfo: userInfo))
      }
      
      guard (error == nil) else {
        sendError("There was an error with your request: \(error!)")
        return
      }
      
      guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 200 && statusCode <= 299 else {
        sendError("Your request returned a status code other than 2xx!")
        return
      }
      
      guard let data = data else {
        sendError("No data was returned by the request!")
        return
      }
      
      completionHandlerForImage(data, nil)
    }
    
    task.resume()
    
    return task
  }
  
  // MARK: Helpers
  
  // substitutes the key for the value that is contained within the method name
  func substituteKeyInMethod(_ method: String, key: String, value: String) -> String? {
    if method.range(of: "{\(key)}") != nil {
      return method.replacingOccurrences(of: "{\(key)}", with: value)
    } else {
      return nil
    }
  }
  
  // given raw JSON, return a usable Foundation object
  private func convertDataWithCompletionHandler(_ data: Data, completionHandlerForConvertData: (_ result: AnyObject?, _ error: NSError?) -> Void) {
    
    var parsedResult: AnyObject! = nil
    do {
      parsedResult = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as AnyObject
    } catch {
      let userInfo = [NSLocalizedDescriptionKey : "Could not parse the data as JSON: '\(data)'"]
      completionHandlerForConvertData(nil, NSError(domain: "convertDataWithCompletionHandler", code: 1, userInfo: userInfo))
    }
    
    completionHandlerForConvertData(parsedResult, nil)
  }
  
  // create a URL from parameters
  private func tmdbURLFromParameters(_ parameters: [String:AnyObject], withPathExtension: String? = nil) -> URL {
    
    var components = URLComponents()
    components.scheme = TMDBClient.Constants.ApiScheme
    components.host = TMDBClient.Constants.ApiHost
    components.path = TMDBClient.Constants.ApiPath + (withPathExtension ?? "")
    components.queryItems = [URLQueryItem]()
    
    for (key, value) in parameters {
      let queryItem = URLQueryItem(name: key, value: "\(value)")
      components.queryItems!.append(queryItem)
    }
    
    return components.url!
  }
  
  // MARK: Shared Instance
  
  class func sharedInstance() -> TMDBClient {
    struct Singleton {
      static var sharedInstance = TMDBClient()
    }
    return Singleton.sharedInstance
  }
}
