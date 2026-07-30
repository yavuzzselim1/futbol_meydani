import 'package:supabase_flutter/supabase_flutter.dart';
void test() {
  Supabase.instance.client.auth.resend(type: OtpType.emailChange, email: 'test@test.com');
}
