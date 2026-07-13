import 'package:flutter/widgets.dart';

/// The app's root navigator key. Wired into the [GoRouter] so code without a
/// [BuildContext] can reach the navigator/overlay — used only by the debug
/// rewarded-ad fake to present its simulated ad, mirroring the real AdMob SDK
/// which presents a full-screen ad. Never used to bypass normal navigation.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
