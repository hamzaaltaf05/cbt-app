import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cbt_app/cubits/auth/auth_cubit.dart';
import 'package:cbt_app/cubits/auth/auth_state.dart';
import 'package:cbt_app/cubits/facility_issues/facility_issues_cubit.dart';
import 'package:cbt_app/cubits/honour_shop/honour_shop_cubit.dart';
import 'package:cbt_app/cubits/notifications/notifications_cubit.dart';
import 'package:cbt_app/screens/login_screen.dart';
import 'package:cbt_app/screens/main_shell.dart';
import 'package:cbt_app/services/fcm_service.dart';
import 'package:cbt_app/utils/env.dart';
import 'package:cbt_app/utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase & background handler
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  // Initialize Supabase with environment variables
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabaseAnonKey,
  );

  // Initialize FCM service (tokens, permissions, foreground banner)
  try {
    await FCMService.instance.init();
  } catch (e) {
    debugPrint('FCMService initialization error: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;

    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>(create: (_) => AuthCubit(client)),
        BlocProvider<NotificationsCubit>(create: (_) => NotificationsCubit(client)),
        BlocProvider<HonourShopCubit>(create: (_) => HonourShopCubit(client)),
        BlocProvider<FacilityIssuesCubit>(create: (_) => FacilityIssuesCubit(client)),
      ],
      child: MaterialApp(
        title: 'Convergent',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        home: const AuthWrapper(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AppAuthState>(
      builder: (context, state) {
        if (state is AuthAuthenticated) {
          return const MainShell();
        } else if (state is AuthUnauthenticated) {
          return const LoginScreen();
        }

        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }
}
