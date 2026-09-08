/// Public anon key — safe in the client. Never put the service_role key here.
class SupabaseConfig {
  static const url = 'https://cadgamdyqpfpcgzifjbx.supabase.co';
  static const anonKey = 'sb_publishable_X6CIAbrYSKlY_iz1mDYcSw_rQjqIoX0';

  /// Auth needs an email. Players only type NOMBRE; we map it to this mailbox.
  static String emailFromNombre(String nombre) {
    final slug = nombre.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return '$slug@players.darbala.app';
  }
}
