/// Public anon key — safe in the client. Never put the service_role key here.
///
/// Auth still requires an email column. Players only type NOMBRE.
/// We invent an address they never see. The domain must have real MX
/// records or Supabase returns "Email address is invalid".
class SupabaseConfig {
  static const url = 'https://cadgamdyqpfpcgzifjbx.supabase.co';
  static const anonKey = 'sb_publishable_X6CIAbrYSKlY_iz1mDYcSw_rQjqIoX0';

  static String emailFromNombre(String nombre) {
    final slug = nombre.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return 'darbala+$slug@gmail.com';
  }
}
