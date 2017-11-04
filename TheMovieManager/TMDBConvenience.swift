import UIKit
import Foundation

// MARK: - TMDBClient

extension TMDBClient {
  
  // MARK: Authentication (GET) Methods
  
  
  /// Authenticates using authentication method of TMDB
  ///
  /// - Parameters:
  ///   - hostViewController: [ViewController]
  ///   - completionHandlerForAuth: Method to receive authentication information
  func authenticateWithViewController(_ hostViewController: UIViewController, completionHandlerForAuth: @escaping (_ success: Bool, _ errorString: String?) -> Void) {
    
    // Request Authentication Token
    getRequestToken() { (success, requestToken, errorString) in
      if success {
        self.requestToken = requestToken
        
        // Validate Received Token
        self.loginWithToken(requestToken, hostViewController: hostViewController) { (success, errorString) in
          if success {
            
            // Create Session
            self.getSessionID(requestToken) { (success, sessionID, errorString) in
              if success {
                self.sessionID = sessionID
                
                // Get User ID
                self.getUserID() { (success, userID, errorString) in
                  if success {
                    if let userID = userID {
                      self.userID = userID
                    }
                  }
                  completionHandlerForAuth(success, errorString)
                }
              } else {
                completionHandlerForAuth(success, errorString)
              }
            }
          } else {
            completionHandlerForAuth(success, errorString)
          }
        }
      } else {
        completionHandlerForAuth(success, errorString)
      }
    }
  }
  
  
  /// Performs the request for get an api Token
  ///
  /// - Parameter completionHandlerForToken: Callback to executed after request is performed
  private func getRequestToken(_ completionHandlerForToken: @escaping (_ success: Bool, _ requestToken: String?, _ errorString: String?) -> Void) {
    
    let parameters = [String:AnyObject]()
    let _ = taskForGETMethod(Methods.AuthenticationTokenNew, parameters: parameters) { (results, error) in
      
      if let error = error {
        print(error)
        completionHandlerForToken(false, nil, "Login Failed (Request Token).")
      } else {
        if let requestToken = results?[TMDBClient.JSONResponseKeys.RequestToken] as? String {
          completionHandlerForToken(true, requestToken, nil)
        } else {
          print("Could not find \(TMDBClient.JSONResponseKeys.RequestToken) in \(results!)")
          completionHandlerForToken(false, nil, "Login Failed (Request Token).")
        }
      }
    }
  }
  
  
  /// Validates received Token linking it with the user information
  ///
  /// - Parameters:
  ///   - requestToken: request token to be linked
  ///   - hostViewController: [ViewController]
  ///   - completionHandlerForLogin: Callback to executed after request is performed
  private func loginWithToken(_ requestToken: String?, hostViewController: UIViewController, completionHandlerForLogin: @escaping (_ success: Bool, _ errorString: String?) -> Void) {
    
    let authorizationURL = URL(string: "\(TMDBClient.Constants.AuthorizationURL)\(requestToken!)")
    let request = URLRequest(url: authorizationURL!)
    let webAuthViewController = hostViewController.storyboard!.instantiateViewController(withIdentifier: "TMDBAuthViewController") as! TMDBAuthViewController
    webAuthViewController.urlRequest = request
    webAuthViewController.requestToken = requestToken
    webAuthViewController.completionHandlerForView = completionHandlerForLogin
    
    let webAuthNavigationController = UINavigationController()
    webAuthNavigationController.pushViewController(webAuthViewController, animated: false)
    
    performUIUpdatesOnMain {
      hostViewController.present(webAuthNavigationController, animated: true, completion: nil)
    }
  }
  
  
  /// Creates a new session using the valid request token
  ///
  /// - Parameters:
  ///   - requestToken: valid request token
  ///   - completionHandlerForSession: Callback to executed after request is performed
  private func getSessionID(_ requestToken: String?, completionHandlerForSession: @escaping (_ success: Bool, _ sessionID: String?, _ errorString: String?) -> Void) {
    
    let parameters = [TMDBClient.ParameterKeys.RequestToken: requestToken!]
    let _ = taskForGETMethod(Methods.AuthenticationSessionNew, parameters: parameters as [String:AnyObject]) { (results, error) in
      if let error = error {
        print(error)
        completionHandlerForSession(false, nil, "Login Failed (Session ID).")
      } else {
        if let sessionID = results?[TMDBClient.JSONResponseKeys.SessionID] as? String {
          completionHandlerForSession(true, sessionID, nil)
        } else {
          print("Could not find \(TMDBClient.JSONResponseKeys.SessionID) in \(results!)")
          completionHandlerForSession(false, nil, "Login Failed (Session ID).")
        }
      }
    }
  }
  
  
  /// Obtains User information
  ///
  /// - Parameter completionHandlerForUserID: Callback to executed after request is performed
  private func getUserID(_ completionHandlerForUserID: @escaping (_ success: Bool, _ userID: Int?, _ errorString: String?) -> Void) {
    
    let parameters = [TMDBClient.ParameterKeys.SessionID: TMDBClient.sharedInstance().sessionID!]
    let _ = taskForGETMethod(Methods.Account, parameters: parameters as [String:AnyObject]) { (results, error) in
      
      /* 3. Send the desired value(s) to completion handler */
      if let error = error {
        print(error)
        completionHandlerForUserID(false, nil, "Login Failed (User ID).")
      } else {
        if let userID = results?[TMDBClient.JSONResponseKeys.UserID] as? Int {
          completionHandlerForUserID(true, userID, nil)
        } else {
          print("Could not find \(TMDBClient.JSONResponseKeys.UserID) in \(results!)")
          completionHandlerForUserID(false, nil, "Login Failed (User ID).")
        }
      }
    }
  }
  
  // MARK: GET Convenience Methods
  
  
  /// Gets user's favorite moview
  ///
  /// - Parameter completionHandlerForFavMovies: Callback to executed after request is performed
  func getFavoriteMovies(_ completionHandlerForFavMovies: @escaping (_ result: [TMDBMovie]?, _ error: NSError?) -> Void) {
    
    let parameters = [TMDBClient.ParameterKeys.SessionID: TMDBClient.sharedInstance().sessionID!]
    var mutableMethod: String = Methods.AccountIDFavoriteMovies
    mutableMethod = substituteKeyInMethod(mutableMethod, key: TMDBClient.URLKeys.UserID, value: String(TMDBClient.sharedInstance().userID!))!
    
    let _ = taskForGETMethod(mutableMethod, parameters: parameters as [String:AnyObject]) { (results, error) in
      
      if let error = error {
        completionHandlerForFavMovies(nil, error)
      } else {
        
        if let results = results?[TMDBClient.JSONResponseKeys.MovieResults] as? [[String:AnyObject]] {
          
          let movies = TMDBMovie.moviesFromResults(results)
          completionHandlerForFavMovies(movies, nil)
        } else {
          completionHandlerForFavMovies(nil, NSError(domain: "getFavoriteMovies parsing", code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not parse getFavoriteMovies"]))
        }
      }
    }
  }
  
  
  /// Gets user's movies watchlist
  ///
  /// - Parameter completionHandlerForWatchlist: Callback to executed after request is performed
  func getWatchlistMovies(_ completionHandlerForWatchlist: @escaping (_ result: [TMDBMovie]?, _ error: NSError?) -> Void) {
    
    let parameters = [TMDBClient.ParameterKeys.SessionID: TMDBClient.sharedInstance().sessionID!] as [String: AnyObject]
    let userId = TMDBClient.sharedInstance().userID!
    let method = TMDBClient.Methods.AccountIDWatchlistMovies.replacingOccurrences(of: "{id}", with: "\(userId)")
    let _ = taskForGETMethod(method, parameters: parameters) { result, error in
      guard let result = result else {
        completionHandlerForWatchlist(nil, error)
        return
      }
      
      if let results = result[TMDBClient.JSONResponseKeys.MovieResults] as? [[String:AnyObject]] {
        
        let movies = TMDBMovie.moviesFromResults(results)
        completionHandlerForWatchlist(movies, nil)
        return
      } else {
        completionHandlerForWatchlist(nil, NSError(domain: "getMoviesForSearchString parsing", code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not parse getMoviesForSearchString"]))
      }
    }
  }
  
  
  /// Searches a movie by specific text using TMDB api
  ///
  /// - Parameters:
  ///   - searchString: target text
  ///   - completionHandlerForMovies: Callback to executed after request is performed
  func getMoviesForSearchString(_ searchString: String, completionHandlerForMovies: @escaping (_ result: [TMDBMovie]?, _ error: NSError?) -> Void) -> URLSessionDataTask? {
    
    let parameters = [TMDBClient.ParameterKeys.Query: searchString]
    let task = taskForGETMethod(Methods.SearchMovie, parameters: parameters as [String:AnyObject]) { (results, error) in
      
      if let error = error {
        completionHandlerForMovies(nil, error)
      } else {
        
        if let results = results?[TMDBClient.JSONResponseKeys.MovieResults] as? [[String:AnyObject]] {
          
          let movies = TMDBMovie.moviesFromResults(results)
          completionHandlerForMovies(movies, nil)
        } else {
          completionHandlerForMovies(nil, NSError(domain: "getMoviesForSearchString parsing", code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not parse getMoviesForSearchString"]))
        }
      }
    }
    
    return task
  }
  
  
  /// Gets user's configuration
  ///
  /// - Parameter completionHandlerForConfig: Callback to executed after request is performed
  func getConfig(_ completionHandlerForConfig: @escaping (_ didSucceed: Bool, _ error: NSError?) -> Void) {
    
    let parameters = [String:AnyObject]()
    let _ = taskForGETMethod(Methods.Config, parameters: parameters as [String:AnyObject]) { (results, error) in
      
      if let error = error {
        completionHandlerForConfig(false, error)
      } else if let newConfig = TMDBConfig(dictionary: results as! [String:AnyObject]) {
        self.config = newConfig
        completionHandlerForConfig(true, nil)
      } else {
        completionHandlerForConfig(false, NSError(domain: "getConfig parsing", code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not parse getConfig"]))
      }
    }
  }
  
  // MARK: POST Convenience Methods
  
  
  /// Favorites/Unfavorites a movie on TMDB user's account
  ///
  /// - Parameters:
  ///   - movie: Movie information
  ///   - favorite: indicates if the movie should be favorited or unfavorited
  ///   - completionHandlerForFavorite: Callback to executed after request is performed
  func postToFavorites(_ movie: TMDBMovie, favorite: Bool, completionHandlerForFavorite: @escaping (_ result: Int?, _ error: NSError?) -> Void) {
    
    let parameters = [TMDBClient.ParameterKeys.SessionID : TMDBClient.sharedInstance().sessionID!]
    var mutableMethod: String = Methods.AccountIDFavorite
    mutableMethod = substituteKeyInMethod(mutableMethod, key: TMDBClient.URLKeys.UserID, value: String(TMDBClient.sharedInstance().userID!))!
    
    let json = [
      TMDBClient.JSONBodyKeys.MediaType: "movie",
      TMDBClient.JSONBodyKeys.MediaID: movie.id,
      TMDBClient.JSONBodyKeys.Favorite: favorite
      ] as [String: AnyObject]
    
    let jsonData = try! JSONSerialization.data(withJSONObject: json, options: [])
    let jsonBody = String(data: jsonData, encoding: String.Encoding.utf8)
    let _ = taskForPOSTMethod(mutableMethod, parameters: parameters as [String:AnyObject], jsonBody: jsonBody!) { (results, error) in
      
      if let error = error {
        completionHandlerForFavorite(nil, error)
      } else {
        if let results = results?[TMDBClient.JSONResponseKeys.StatusCode] as? Int {
          completionHandlerForFavorite(results, nil)
        } else {
          completionHandlerForFavorite(nil, NSError(domain: "postToFavoritesList parsing", code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not parse postToFavoritesList"]))
        }
      }
    }
  }
  
  
  /// Adds/Removes a movie from TMDB user's watchlist
  ///
  /// - Parameters:
  ///   - movie: Movie information
  ///   - watchlist: indicates if the moview should be added or removed
  ///   - completionHandlerForWatchlist: Callback to executed after request is performed
  func postToWatchlist(_ movie: TMDBMovie, watchlist: Bool, completionHandlerForWatchlist: @escaping (_ result: Int?, _ error: NSError?) -> Void) {
    
    let parameters = [TMDBClient.ParameterKeys.SessionID : TMDBClient.sharedInstance().sessionID!]
    var mutableMethod: String = Methods.AccountIDWatchlist
    mutableMethod = substituteKeyInMethod(mutableMethod, key: TMDBClient.URLKeys.UserID, value: String(TMDBClient.sharedInstance().userID!))!
    
    let json = [
      TMDBClient.JSONBodyKeys.MediaType: "movie",
      TMDBClient.JSONBodyKeys.MediaID: movie.id,
      TMDBClient.JSONBodyKeys.Watchlist: watchlist
    ] as [String: AnyObject]
    
    let jsonData = try! JSONSerialization.data(withJSONObject: json, options: [])
    let jsonBody = String(data: jsonData, encoding: String.Encoding.utf8)
    
    let _ = taskForPOSTMethod(mutableMethod, parameters: parameters as [String:AnyObject], jsonBody: jsonBody!) { (results, error) in
      
      if let error = error {
        completionHandlerForWatchlist(nil, error)
      } else {
        if let results = results?[TMDBClient.JSONResponseKeys.StatusCode] as? Int {
          completionHandlerForWatchlist(results, nil)
        } else {
          completionHandlerForWatchlist(nil, NSError(domain: "postToFavoritesList parsing", code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not parse postToFavoritesList"]))
        }
      }
    }
  }
}
