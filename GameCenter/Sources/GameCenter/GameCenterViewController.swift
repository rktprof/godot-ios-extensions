#if os(iOS)
import SwiftGodot
import GameKit
import UIKit

class UIGameCenterViewController: UIViewController, GKGameCenterControllerDelegate
{
	var onControllerClosed:Callable? = nil

	func showUIController(_ viewController:GKGameCenterViewController, onClose:Callable?)
	{
		do
		{
			// TODO: Make sure we don't try to open more than one view
			onControllerClosed = onClose
			viewController.gameCenterDelegate = self
			try getRootController()?.present(viewController, animated: true, completion: nil)
		}
		catch
		{
			GD.pushError("Error: \(error).")
		}
	}

	func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController)
	{
    	gameCenterViewController.dismiss(animated:true, completion: { self.onControllerClosed?.call() })
	}

	func getRootController() -> UIViewController?
	{
		return getMainWindow()?.rootViewController
	}

	func getMainWindow() -> UIWindow?
	{
		// As seen on: https://sarunw.com/posts/how-to-get-root-view-controller/
		// NOTE: Does not neccessarily show in the correct window if there are multiple windows
		return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .first?.windows
            .first(where: \.isKeyWindow)
	}
}

#endif