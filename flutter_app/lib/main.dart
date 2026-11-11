import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';

const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://pjewrbblgnchzlznlpld.supabase.co',
);
const supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'sb_publishable_b1FijMpj7rSLWdPDnyA-XA_tDNBnYFh',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );
  runApp(const VirilApp());
}
