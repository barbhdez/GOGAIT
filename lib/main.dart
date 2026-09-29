import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
// hide Path: choca con el Path de dart:ui que usan los CustomPainter
import 'package:latlong2/latlong.dart' hide Path;
import 'firebase_options.dart';

// ---- CONSTANTS & THEME ----
// Pie evita duplicar variables/funciones de conexión-calibración por lado
enum Pie { derecha, izquierda }

class FootBleId {
  final String nombre, servicioUuid, caracteristicaUuid;
  const FootBleId(this.nombre, this.servicioUuid, this.caracteristicaUuid);
}

const FootBleId _kBleDerecha = FootBleId(
    "GOGAIT_XIAO_DERECHA",
    "4fafc201-1fb5-459e-8fcc-c5c9c331914b",
    "beb5483e-36e1-4688-b7f5-ea07361b26a8");
const FootBleId _kBleIzquierda = FootBleId(
    "GOGAIT_XIAO_IZQUIERDA",
    "b9058af5-cb7a-4de0-8753-67184b634064",
    "7886f4fc-3ad6-4f8d-b0bf-62bea816a66f");

FootBleId idBlePara(Pie pie) =>
    pie == Pie.derecha ? _kBleDerecha : _kBleIzquierda;
String etiquetaPie(Pie pie) =>
    pie == Pie.derecha ? tr('side_right') : tr('side_left');

// ---- IDIOMA / TRADUCCIONES ----
// Traducción propia en vez de intl/ARB, appLang es ValueNotifier global
enum AppLang { en, es, fr, de, it, pt }

extension AppLangInfo on AppLang {
  String get flag => switch (this) {
        AppLang.en => '🇬🇧',
        AppLang.es => '🇪🇸',
        AppLang.fr => '🇫🇷',
        AppLang.de => '🇩🇪',
        AppLang.it => '🇮🇹',
        AppLang.pt => '🇵🇹',
      };
  String get nombreNativo => switch (this) {
        AppLang.en => 'English',
        AppLang.es => 'Español',
        AppLang.fr => 'Français',
        AppLang.de => 'Deutsch',
        AppLang.it => 'Italiano',
        AppLang.pt => 'Português',
      };
  String get codigo => name;
}

final ValueNotifier<AppLang> appLang = ValueNotifier(AppLang.en);
const String _claveIdioma = 'app_lang';

Future<void> cargarIdiomaGuardado() async {
  final prefs = await SharedPreferences.getInstance();
  final codigo = prefs.getString(_claveIdioma);
  if (codigo != null) {
    appLang.value = AppLang.values.firstWhere((l) => l.codigo == codigo,
        orElse: () => AppLang.en);
  }
}

Future<void> cambiarIdioma(AppLang nuevo) async {
  appLang.value = nuevo;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_claveIdioma, nuevo.codigo);
}

// Claves de traducción de las pantallas ya migradas, se van añadiendo poco a poco
final Map<String, Map<AppLang, String>> _traducciones = {
  'splash_analyzing': {
    AppLang.en: 'Analyzing movement',
    AppLang.es: 'Analizando movimiento',
    AppLang.fr: 'Analyse du mouvement',
    AppLang.de: 'Bewegung wird analysiert',
    AppLang.it: 'Analisi del movimento',
    AppLang.pt: 'A analisar o movimento',
  },
  'splash_connecting': {
    AppLang.en: 'Connecting smart biomechanics',
    AppLang.es: 'Conectando biomecánica inteligente',
    AppLang.fr: 'Connexion à la biomécanique intelligente',
    AppLang.de: 'Verbindung mit intelligenter Biomechanik',
    AppLang.it: 'Connessione alla biomeccanica intelligente',
    AppLang.pt: 'A ligar à biomecânica inteligente',
  },
  'welcome_tagline': {
    AppLang.en: 'Analyze. Adjust. Achieve.',
    AppLang.es: 'Analyze. Adjust. Achieve.',
    AppLang.fr: 'Analyze. Adjust. Achieve.',
    AppLang.de: 'Analyze. Adjust. Achieve.',
    AppLang.it: 'Analyze. Adjust. Achieve.',
    AppLang.pt: 'Analyze. Adjust. Achieve.',
  },
  'login': {
    AppLang.en: 'Login',
    AppLang.es: 'Iniciar sesión',
    AppLang.fr: 'Connexion',
    AppLang.de: 'Anmelden',
    AppLang.it: 'Accedi',
    AppLang.pt: 'Entrar',
  },
  'register': {
    AppLang.en: 'Register',
    AppLang.es: 'Registrarse',
    AppLang.fr: "S'inscrire",
    AppLang.de: 'Registrieren',
    AppLang.it: 'Registrati',
    AppLang.pt: 'Registar',
  },
  'welcome_footer': {
    AppLang.en: 'Advanced biomechanical analysis',
    AppLang.es: 'Análisis biomecánico avanzado',
    AppLang.fr: 'Analyse biomécanique avancée',
    AppLang.de: 'Fortgeschrittene biomechanische Analyse',
    AppLang.it: 'Analisi biomeccanica avanzata',
    AppLang.pt: 'Análise biomecânica avançada',
  },
  'select_language': {
    AppLang.en: 'Select language',
    AppLang.es: 'Seleccionar idioma',
    AppLang.fr: 'Choisir la langue',
    AppLang.de: 'Sprache wählen',
    AppLang.it: 'Seleziona lingua',
    AppLang.pt: 'Selecionar idioma',
  },
  'complete_profile_title': {
    AppLang.en: 'Almost there',
    AppLang.es: 'Ya casi',
    AppLang.fr: 'Presque terminé',
    AppLang.de: 'Fast geschafft',
    AppLang.it: 'Quasi fatto',
    AppLang.pt: 'Quase lá',
  },
  'complete_profile_message': {
    AppLang.en: 'Fill in your data before starting any analysis.',
    AppLang.es: 'Rellena tus datos antes de empezar cualquier análisis.',
    AppLang.fr: 'Renseignez vos données avant de commencer une analyse.',
    AppLang.de: 'Geben Sie Ihre Daten ein, bevor Sie eine Analyse starten.',
    AppLang.it: 'Inserisci i tuoi dati prima di iniziare qualsiasi analisi.',
    AppLang.pt: 'Preencha os seus dados antes de iniciar qualquer análise.',
  },
  'complete_profile_button': {
    AppLang.en: 'Complete my profile',
    AppLang.es: 'Completar mi perfil',
    AppLang.fr: 'Compléter mon profil',
    AppLang.de: 'Mein Profil vervollständigen',
    AppLang.it: 'Completa il mio profilo',
    AppLang.pt: 'Completar o meu perfil',
  },
  // ── Login ──
  'login_welcome_back': {
    AppLang.en: 'Welcome Back',
    AppLang.es: 'Bienvenido de nuevo',
    AppLang.fr: 'Content de vous revoir',
    AppLang.de: 'Willkommen zurück',
    AppLang.it: 'Bentornato',
    AppLang.pt: 'Bem-vindo de volta',
  },
  'login_subtitle': {
    AppLang.en: 'Sign in to continue your journey',
    AppLang.es: 'Inicia sesión para continuar tu progreso',
    AppLang.fr: 'Connectez-vous pour poursuivre votre parcours',
    AppLang.de: 'Melde dich an, um fortzufahren',
    AppLang.it: 'Accedi per continuare il tuo percorso',
    AppLang.pt: 'Inicie sessão para continuar a sua jornada',
  },
  'email_label': {
    AppLang.en: 'Email',
    AppLang.es: 'Correo electrónico',
    AppLang.fr: 'E-mail',
    AppLang.de: 'E-Mail',
    AppLang.it: 'Email',
    AppLang.pt: 'Email',
  },
  'email_hint': {
    AppLang.en: 'your@email.com',
    AppLang.es: 'tu@email.com',
    AppLang.fr: 'votre@email.com',
    AppLang.de: 'deine@email.com',
    AppLang.it: 'tua@email.com',
    AppLang.pt: 'seu@email.com',
  },
  'password_label': {
    AppLang.en: 'Password',
    AppLang.es: 'Contraseña',
    AppLang.fr: 'Mot de passe',
    AppLang.de: 'Passwort',
    AppLang.it: 'Password',
    AppLang.pt: 'Palavra-passe',
  },
  'password_hint': {
    AppLang.en: 'Enter your password',
    AppLang.es: 'Introduce tu contraseña',
    AppLang.fr: 'Entrez votre mot de passe',
    AppLang.de: 'Passwort eingeben',
    AppLang.it: 'Inserisci la password',
    AppLang.pt: 'Introduza a sua palavra-passe',
  },
  'forgot_password': {
    AppLang.en: 'Forgot password?',
    AppLang.es: '¿Olvidaste tu contraseña?',
    AppLang.fr: 'Mot de passe oublié ?',
    AppLang.de: 'Passwort vergessen?',
    AppLang.it: 'Password dimenticata?',
    AppLang.pt: 'Esqueceu-se da palavra-passe?',
  },
  'no_account': {
    AppLang.en: "Don't have an account? ",
    AppLang.es: '¿No tienes cuenta? ',
    AppLang.fr: "Vous n'avez pas de compte ? ",
    AppLang.de: 'Kein Konto? ',
    AppLang.it: 'Non hai un account? ',
    AppLang.pt: 'Não tem conta? ',
  },
  'register_here': {
    AppLang.en: 'Register here',
    AppLang.es: 'Regístrate aquí',
    AppLang.fr: "S'inscrire ici",
    AppLang.de: 'Hier registrieren',
    AppLang.it: 'Registrati qui',
    AppLang.pt: 'Registe-se aqui',
  },
  'err_invalid_email': {
    AppLang.en: 'Please enter a valid email address',
    AppLang.es: 'Introduce un correo electrónico válido',
    AppLang.fr: 'Veuillez saisir une adresse e-mail valide',
    AppLang.de: 'Bitte gib eine gültige E-Mail-Adresse ein',
    AppLang.it: 'Inserisci un indirizzo email valido',
    AppLang.pt: 'Introduza um endereço de email válido',
  },
  'err_enter_password': {
    AppLang.en: 'Please enter your password',
    AppLang.es: 'Introduce tu contraseña',
    AppLang.fr: 'Veuillez saisir votre mot de passe',
    AppLang.de: 'Bitte gib dein Passwort ein',
    AppLang.it: 'Inserisci la tua password',
    AppLang.pt: 'Introduza a sua palavra-passe',
  },
  'err_user_not_found': {
    AppLang.en: 'This email is not registered',
    AppLang.es: 'Este correo no está registrado',
    AppLang.fr: "Cet e-mail n'est pas enregistré",
    AppLang.de: 'Diese E-Mail ist nicht registriert',
    AppLang.it: 'Questa email non è registrata',
    AppLang.pt: 'Este email não está registado',
  },
  'err_wrong_password': {
    AppLang.en: 'Incorrect password',
    AppLang.es: 'Contraseña incorrecta',
    AppLang.fr: 'Mot de passe incorrect',
    AppLang.de: 'Falsches Passwort',
    AppLang.it: 'Password errata',
    AppLang.pt: 'Palavra-passe incorreta',
  },
  'err_invalid_email_format': {
    AppLang.en: 'Invalid email format',
    AppLang.es: 'Formato de correo no válido',
    AppLang.fr: "Format d'e-mail invalide",
    AppLang.de: 'Ungültiges E-Mail-Format',
    AppLang.it: 'Formato email non valido',
    AppLang.pt: 'Formato de email inválido',
  },
  'err_too_many_attempts': {
    AppLang.en: 'Too many attempts. Try again later',
    AppLang.es: 'Demasiados intentos. Inténtalo más tarde',
    AppLang.fr: 'Trop de tentatives. Réessayez plus tard',
    AppLang.de: 'Zu viele Versuche. Später erneut versuchen',
    AppLang.it: 'Troppi tentativi. Riprova più tardi',
    AppLang.pt: 'Demasiadas tentativas. Tente mais tarde',
  },
  'err_login_generic': {
    AppLang.en: 'Login error',
    AppLang.es: 'Error al iniciar sesión',
    AppLang.fr: 'Erreur de connexion',
    AppLang.de: 'Anmeldefehler',
    AppLang.it: "Errore di accesso",
    AppLang.pt: 'Erro ao iniciar sessão',
  },
  'err_enter_email_first': {
    AppLang.en: 'Enter your email first to reset your password',
    AppLang.es: 'Introduce primero tu correo para restablecer la contraseña',
    AppLang.fr: "Saisissez d'abord votre e-mail pour réinitialiser le mot de passe",
    AppLang.de: 'Gib zuerst deine E-Mail ein, um das Passwort zurückzusetzen',
    AppLang.it: 'Inserisci prima la tua email per reimpostare la password',
    AppLang.pt: 'Introduza primeiro o seu email para repor a palavra-passe',
  },
  'password_reset_sent': {
    AppLang.en: 'Password reset email sent. Check your inbox.',
    AppLang.es: 'Correo de restablecimiento enviado. Revisa tu bandeja.',
    AppLang.fr: 'E-mail de réinitialisation envoyé. Vérifiez votre boîte de réception.',
    AppLang.de: 'E-Mail zum Zurücksetzen gesendet. Prüfe dein Postfach.',
    AppLang.it: 'Email di reimpostazione inviata. Controlla la posta in arrivo.',
    AppLang.pt: 'Email de recuperação enviado. Verifique a sua caixa de entrada.',
  },
  'error_prefix': {
    AppLang.en: 'Error',
    AppLang.es: 'Error',
    AppLang.fr: 'Erreur',
    AppLang.de: 'Fehler',
    AppLang.it: 'Errore',
    AppLang.pt: 'Erro',
  },
  // ── Registro ──
  'reg_create_account': {
    AppLang.en: 'Create Account',
    AppLang.es: 'Crear cuenta',
    AppLang.fr: 'Créer un compte',
    AppLang.de: 'Konto erstellen',
    AppLang.it: 'Crea account',
    AppLang.pt: 'Criar conta',
  },
  'reg_step_of': {
    AppLang.en: 'Step {n} of 4',
    AppLang.es: 'Paso {n} de 4',
    AppLang.fr: 'Étape {n} sur 4',
    AppLang.de: 'Schritt {n} von 4',
    AppLang.it: 'Passo {n} di 4',
    AppLang.pt: 'Passo {n} de 4',
  },
  'reg_personal_info': {
    AppLang.en: 'Personal Information',
    AppLang.es: 'Información personal',
    AppLang.fr: 'Informations personnelles',
    AppLang.de: 'Persönliche Angaben',
    AppLang.it: 'Informazioni personali',
    AppLang.pt: 'Informação pessoal',
  },
  'first_name': {
    AppLang.en: 'First Name',
    AppLang.es: 'Nombre',
    AppLang.fr: 'Prénom',
    AppLang.de: 'Vorname',
    AppLang.it: 'Nome',
    AppLang.pt: 'Nome próprio',
  },
  'last_name': {
    AppLang.en: 'Last Name',
    AppLang.es: 'Apellidos',
    AppLang.fr: 'Nom',
    AppLang.de: 'Nachname',
    AppLang.it: 'Cognome',
    AppLang.pt: 'Apelido',
  },
  'password_hint_rules': {
    AppLang.en: 'Min 6 chars, 1 uppercase, 1 number',
    AppLang.es: 'Mín. 6 caracteres, 1 mayúscula, 1 número',
    AppLang.fr: 'Min 6 caractères, 1 majuscule, 1 chiffre',
    AppLang.de: 'Min. 6 Zeichen, 1 Großbuchstabe, 1 Zahl',
    AppLang.it: 'Min. 6 caratteri, 1 maiuscola, 1 numero',
    AppLang.pt: 'Mín. 6 caracteres, 1 maiúscula, 1 número',
  },
  'reg_date_of_birth': {
    AppLang.en: 'Date of Birth',
    AppLang.es: 'Fecha de nacimiento',
    AppLang.fr: 'Date de naissance',
    AppLang.de: 'Geburtsdatum',
    AppLang.it: 'Data di nascita',
    AppLang.pt: 'Data de nascimento',
  },
  'reg_physical_metrics': {
    AppLang.en: 'Physical Metrics',
    AppLang.es: 'Medidas físicas',
    AppLang.fr: 'Mesures physiques',
    AppLang.de: 'Körperliche Daten',
    AppLang.it: 'Misure fisiche',
    AppLang.pt: 'Medidas físicas',
  },
  'height': {
    AppLang.en: 'Height',
    AppLang.es: 'Altura',
    AppLang.fr: 'Taille',
    AppLang.de: 'Größe',
    AppLang.it: 'Altezza',
    AppLang.pt: 'Altura',
  },
  'weight': {
    AppLang.en: 'Weight',
    AppLang.es: 'Peso',
    AppLang.fr: 'Poids',
    AppLang.de: 'Gewicht',
    AppLang.it: 'Peso',
    AppLang.pt: 'Peso',
  },
  'shoe_size_eu': {
    AppLang.en: 'Shoe Size (EU)',
    AppLang.es: 'Talla de zapato (EU)',
    AppLang.fr: 'Pointure (EU)',
    AppLang.de: 'Schuhgröße (EU)',
    AppLang.it: 'Numero di scarpe (EU)',
    AppLang.pt: 'Tamanho de calçado (EU)',
  },
  'gender': {
    AppLang.en: 'Gender',
    AppLang.es: 'Género',
    AppLang.fr: 'Genre',
    AppLang.de: 'Geschlecht',
    AppLang.it: 'Genere',
    AppLang.pt: 'Género',
  },
  'male': {
    AppLang.en: 'Male',
    AppLang.es: 'Hombre',
    AppLang.fr: 'Homme',
    AppLang.de: 'Männlich',
    AppLang.it: 'Uomo',
    AppLang.pt: 'Masculino',
  },
  'female': {
    AppLang.en: 'Female',
    AppLang.es: 'Mujer',
    AppLang.fr: 'Femme',
    AppLang.de: 'Weiblich',
    AppLang.it: 'Donna',
    AppLang.pt: 'Feminino',
  },
  'reg_foot_biomechanics': {
    AppLang.en: 'Foot Biomechanics',
    AppLang.es: 'Biomecánica del pie',
    AppLang.fr: 'Biomécanique du pied',
    AppLang.de: 'Fuß-Biomechanik',
    AppLang.it: 'Biomeccanica del piede',
    AppLang.pt: 'Biomecânica do pé',
  },
  'foot_arch_type': {
    AppLang.en: 'Foot Arch Type',
    AppLang.es: 'Tipo de arco plantar',
    AppLang.fr: 'Type de voûte plantaire',
    AppLang.de: 'Fußgewölbetyp',
    AppLang.it: 'Tipo di arco plantare',
    AppLang.pt: 'Tipo de arco plantar',
  },
  'arch_flat': {
    AppLang.en: 'Flat',
    AppLang.es: 'Plano',
    AppLang.fr: 'Plat',
    AppLang.de: 'Flach',
    AppLang.it: 'Piatto',
    AppLang.pt: 'Plano',
  },
  'arch_normal': {
    AppLang.en: 'Normal',
    AppLang.es: 'Normal',
    AppLang.fr: 'Normal',
    AppLang.de: 'Normal',
    AppLang.it: 'Normale',
    AppLang.pt: 'Normal',
  },
  'arch_high': {
    AppLang.en: 'High',
    AppLang.es: 'Alto',
    AppLang.fr: 'Haute',
    AppLang.de: 'Hoch',
    AppLang.it: 'Alto',
    AppLang.pt: 'Alto',
  },
  'reg_arch_info': {
    AppLang.en:
        'Your foot arch type affects your gait pattern and pressure distribution. This helps us provide personalized analysis.',
    AppLang.es:
        'Tu tipo de arco plantar afecta a tu patrón de marcha y a la distribución de presión. Esto nos ayuda a ofrecerte un análisis personalizado.',
    AppLang.fr:
        'Le type de votre voûte plantaire affecte votre démarche et la répartition de la pression. Cela nous aide à fournir une analyse personnalisée.',
    AppLang.de:
        'Dein Fußgewölbetyp beeinflusst dein Gangmuster und die Druckverteilung. Das hilft uns, eine personalisierte Analyse zu erstellen.',
    AppLang.it:
        'Il tuo tipo di arco plantare influisce sul pattern del passo e sulla distribuzione della pressione. Questo ci aiuta a fornire un\'analisi personalizzata.',
    AppLang.pt:
        'O seu tipo de arco plantar afeta o seu padrão de marcha e a distribuição de pressão. Isto ajuda-nos a fornecer uma análise personalizada.',
  },
  'reg_health_info_title': {
    AppLang.en: 'Health Information',
    AppLang.es: 'Información de salud',
    AppLang.fr: 'Informations de santé',
    AppLang.de: 'Gesundheitsangaben',
    AppLang.it: 'Informazioni sulla salute',
    AppLang.pt: 'Informação de saúde',
  },
  'reg_health_question': {
    AppLang.en: 'Do you have any foot conditions?',
    AppLang.es: '¿Tienes alguna afección en el pie?',
    AppLang.fr: 'Avez-vous une condition au pied ?',
    AppLang.de: 'Hast du Fußbeschwerden?',
    AppLang.it: 'Hai qualche condizione al piede?',
    AppLang.pt: 'Tem alguma condição no pé?',
  },
  'reg_health_info': {
    AppLang.en:
        'This information helps us provide more accurate biomechanical analysis and personalized recommendations.',
    AppLang.es:
        'Esta información nos ayuda a ofrecer un análisis biomecánico más preciso y recomendaciones personalizadas.',
    AppLang.fr:
        'Ces informations nous aident à fournir une analyse biomécanique plus précise et des recommandations personnalisées.',
    AppLang.de:
        'Diese Angaben helfen uns, eine genauere biomechanische Analyse und personalisierte Empfehlungen zu erstellen.',
    AppLang.it:
        'Queste informazioni ci aiutano a fornire un\'analisi biomeccanica più accurata e consigli personalizzati.',
    AppLang.pt:
        'Esta informação ajuda-nos a fornecer uma análise biomecânica mais precisa e recomendações personalizadas.',
  },
  'back': {
    AppLang.en: 'Back',
    AppLang.es: 'Atrás',
    AppLang.fr: 'Retour',
    AppLang.de: 'Zurück',
    AppLang.it: 'Indietro',
    AppLang.pt: 'Voltar',
  },
  'next': {
    AppLang.en: 'Next',
    AppLang.es: 'Siguiente',
    AppLang.fr: 'Suivant',
    AppLang.de: 'Weiter',
    AppLang.it: 'Avanti',
    AppLang.pt: 'Seguinte',
  },
  'err_first_name': {
    AppLang.en: 'Please enter your first name',
    AppLang.es: 'Introduce tu nombre',
    AppLang.fr: 'Veuillez saisir votre prénom',
    AppLang.de: 'Bitte gib deinen Vornamen ein',
    AppLang.it: 'Inserisci il tuo nome',
    AppLang.pt: 'Introduza o seu nome próprio',
  },
  'err_last_name': {
    AppLang.en: 'Please enter your last name',
    AppLang.es: 'Introduce tus apellidos',
    AppLang.fr: 'Veuillez saisir votre nom',
    AppLang.de: 'Bitte gib deinen Nachnamen ein',
    AppLang.it: 'Inserisci il tuo cognome',
    AppLang.pt: 'Introduza o seu apelido',
  },
  'err_valid_email': {
    AppLang.en: 'Please enter a valid email',
    AppLang.es: 'Introduce un correo electrónico válido',
    AppLang.fr: 'Veuillez saisir un e-mail valide',
    AppLang.de: 'Bitte gib eine gültige E-Mail ein',
    AppLang.it: 'Inserisci un\'email valida',
    AppLang.pt: 'Introduza um email válido',
  },
  'err_password_rules': {
    AppLang.en: 'Password: min 6 chars, 1 uppercase, 1 number',
    AppLang.es: 'Contraseña: mín. 6 caracteres, 1 mayúscula, 1 número',
    AppLang.fr: 'Mot de passe : min 6 caractères, 1 majuscule, 1 chiffre',
    AppLang.de: 'Passwort: min. 6 Zeichen, 1 Großbuchstabe, 1 Zahl',
    AppLang.it: 'Password: min. 6 caratteri, 1 maiuscola, 1 numero',
    AppLang.pt: 'Palavra-passe: mín. 6 caracteres, 1 maiúscula, 1 número',
  },
  'err_dob': {
    AppLang.en: 'Please select your date of birth',
    AppLang.es: 'Selecciona tu fecha de nacimiento',
    AppLang.fr: 'Veuillez sélectionner votre date de naissance',
    AppLang.de: 'Bitte wähle dein Geburtsdatum',
    AppLang.it: 'Seleziona la tua data di nascita',
    AppLang.pt: 'Selecione a sua data de nascimento',
  },
  'err_email_in_use': {
    AppLang.en: 'This email is already registered',
    AppLang.es: 'Este correo ya está registrado',
    AppLang.fr: 'Cet e-mail est déjà enregistré',
    AppLang.de: 'Diese E-Mail ist bereits registriert',
    AppLang.it: 'Questa email è già registrata',
    AppLang.pt: 'Este email já está registado',
  },
  'err_weak_password': {
    AppLang.en: 'Password is too weak',
    AppLang.es: 'La contraseña es demasiado débil',
    AppLang.fr: 'Le mot de passe est trop faible',
    AppLang.de: 'Das Passwort ist zu schwach',
    AppLang.it: 'La password è troppo debole',
    AppLang.pt: 'A palavra-passe é demasiado fraca',
  },
  'err_registration_generic': {
    AppLang.en: 'Registration error',
    AppLang.es: 'Error en el registro',
    AppLang.fr: "Erreur d'inscription",
    AppLang.de: 'Registrierungsfehler',
    AppLang.it: 'Errore di registrazione',
    AppLang.pt: 'Erro no registo',
  },
  // ── Home ──
  'home_hello': {
    AppLang.en: 'Hello, {name}',
    AppLang.es: 'Hola, {name}',
    AppLang.fr: 'Bonjour, {name}',
    AppLang.de: 'Hallo, {name}',
    AppLang.it: 'Ciao, {name}',
    AppLang.pt: 'Olá, {name}',
  },
  'home_subtitle': {
    AppLang.en: 'Ready to analyze your gait?',
    AppLang.es: '¿Listo para analizar tu marcha?',
    AppLang.fr: 'Prêt à analyser votre démarche ?',
    AppLang.de: 'Bereit, deinen Gang zu analysieren?',
    AppLang.it: 'Pronto ad analizzare la tua andatura?',
    AppLang.pt: 'Pronto para analisar a sua marcha?',
  },
  'user_fallback': {
    AppLang.en: 'User',
    AppLang.es: 'Usuario',
    AppLang.fr: 'Utilisateur',
    AppLang.de: 'Nutzer',
    AppLang.it: 'Utente',
    AppLang.pt: 'Utilizador',
  },
  'insoles_connected': {
    AppLang.en: 'Smart Insoles Connected',
    AppLang.es: 'Plantillas conectadas',
    AppLang.fr: 'Semelles connectées',
    AppLang.de: 'Smart-Einlegesohlen verbunden',
    AppLang.it: 'Solette connesse',
    AppLang.pt: 'Palmilhas ligadas',
  },
  'insoles_partial': {
    AppLang.en: 'Smart Insoles Partially Connected',
    AppLang.es: 'Plantillas parcialmente conectadas',
    AppLang.fr: 'Semelles partiellement connectées',
    AppLang.de: 'Smart-Einlegesohlen teilweise verbunden',
    AppLang.it: 'Solette parzialmente connesse',
    AppLang.pt: 'Palmilhas parcialmente ligadas',
  },
  'insoles_disconnected': {
    AppLang.en: 'Smart Insoles Disconnected',
    AppLang.es: 'Plantillas desconectadas',
    AppLang.fr: 'Semelles déconnectées',
    AppLang.de: 'Smart-Einlegesohlen getrennt',
    AppLang.it: 'Solette disconnesse',
    AppLang.pt: 'Palmilhas desligadas',
  },
  'tap_to_connect': {
    AppLang.en: 'Tap to connect',
    AppLang.es: 'Toca para conectar',
    AppLang.fr: 'Appuyez pour connecter',
    AppLang.de: 'Tippen zum Verbinden',
    AppLang.it: 'Tocca per connettere',
    AppLang.pt: 'Toque para ligar',
  },
  'insoles_count': {
    AppLang.en: '{n}/2 insoles',
    AppLang.es: '{n}/2 plantillas',
    AppLang.fr: '{n}/2 semelles',
    AppLang.de: '{n}/2 Sohlen',
    AppLang.it: '{n}/2 solette',
    AppLang.pt: '{n}/2 palmilhas',
  },
  'status_active': {
    AppLang.en: 'Active',
    AppLang.es: 'Activo',
    AppLang.fr: 'Actif',
    AppLang.de: 'Aktiv',
    AppLang.it: 'Attivo',
    AppLang.pt: 'Ativo',
  },
  'status_offline': {
    AppLang.en: 'Offline',
    AppLang.es: 'Sin conexión',
    AppLang.fr: 'Hors ligne',
    AppLang.de: 'Offline',
    AppLang.it: 'Offline',
    AppLang.pt: 'Offline',
  },
  'last_activity': {
    AppLang.en: 'Last Activity',
    AppLang.es: 'Última actividad',
    AppLang.fr: 'Dernière activité',
    AppLang.de: 'Letzte Aktivität',
    AppLang.it: 'Ultima attività',
    AppLang.pt: 'Última atividade',
  },
  'quick_metrics': {
    AppLang.en: 'Quick Metrics',
    AppLang.es: 'Métricas rápidas',
    AppLang.fr: 'Métriques rapides',
    AppLang.de: 'Schnellübersicht',
    AppLang.it: 'Metriche rapide',
    AppLang.pt: 'Métricas rápidas',
  },
  'export_your_data': {
    AppLang.en: 'Export your data',
    AppLang.es: 'Exporta tus datos',
    AppLang.fr: 'Exportez vos données',
    AppLang.de: 'Daten exportieren',
    AppLang.it: 'Esporta i tuoi dati',
    AppLang.pt: 'Exporte os seus dados',
  },
  'metric_balance': {
    AppLang.en: 'Balance',
    AppLang.es: 'Equilibrio',
    AppLang.fr: 'Équilibre',
    AppLang.de: 'Balance',
    AppLang.it: 'Equilibrio',
    AppLang.pt: 'Equilíbrio',
  },
  'metric_impact': {
    AppLang.en: 'Impact',
    AppLang.es: 'Impacto',
    AppLang.fr: 'Impact',
    AppLang.de: 'Impact',
    AppLang.it: 'Impatto',
    AppLang.pt: 'Impacto',
  },
  'metric_cadence': {
    AppLang.en: 'Cadence',
    AppLang.es: 'Cadencia',
    AppLang.fr: 'Cadence',
    AppLang.de: 'Kadenz',
    AppLang.it: 'Cadenza',
    AppLang.pt: 'Cadência',
  },
  'start_analysis': {
    AppLang.en: 'Start Analysis',
    AppLang.es: 'Empezar análisis',
    AppLang.fr: "Démarrer l'analyse",
    AppLang.de: 'Analyse starten',
    AppLang.it: 'Avvia analisi',
    AppLang.pt: 'Iniciar análise',
  },
  'view_history': {
    AppLang.en: 'View History',
    AppLang.es: 'Ver historial',
    AppLang.fr: "Voir l'historique",
    AppLang.de: 'Verlauf ansehen',
    AppLang.it: 'Vedi cronologia',
    AppLang.pt: 'Ver histórico',
  },
  // ── Selección de actividad ──
  'select_activity_title': {
    AppLang.en: 'What are you doing?',
    AppLang.es: '¿Qué vas a hacer?',
    AppLang.fr: 'Que faites-vous ?',
    AppLang.de: 'Was machst du?',
    AppLang.it: 'Cosa stai facendo?',
    AppLang.pt: 'O que vai fazer?',
  },
  'select_activity_subtitle': {
    AppLang.en: "We'll use this to calibrate and label the session.",
    AppLang.es: 'Lo usaremos para calibrar y etiquetar la sesión.',
    AppLang.fr: 'Cela nous servira à calibrer et étiqueter la session.',
    AppLang.de: 'Damit kalibrieren und benennen wir die Sitzung.',
    AppLang.it: 'Lo useremo per calibrare ed etichettare la sessione.',
    AppLang.pt: 'Vamos usar isto para calibrar e identificar a sessão.',
  },
  'activity_walk': {
    AppLang.en: 'Walk',
    AppLang.es: 'Caminar',
    AppLang.fr: 'Marche',
    AppLang.de: 'Gehen',
    AppLang.it: 'Camminata',
    AppLang.pt: 'Caminhada',
  },
  'activity_walk_desc': {
    AppLang.en: 'Casual or fitness walking.',
    AppLang.es: 'Caminata casual o de fitness.',
    AppLang.fr: 'Marche décontractée ou fitness.',
    AppLang.de: 'Lockeres oder sportliches Gehen.',
    AppLang.it: 'Camminata rilassata o fitness.',
    AppLang.pt: 'Caminhada casual ou fitness.',
  },
  'activity_run': {
    AppLang.en: 'Run',
    AppLang.es: 'Correr',
    AppLang.fr: 'Course',
    AppLang.de: 'Laufen',
    AppLang.it: 'Corsa',
    AppLang.pt: 'Corrida',
  },
  'activity_run_desc': {
    AppLang.en: 'Road or treadmill running.',
    AppLang.es: 'Carrera en carretera o cinta.',
    AppLang.fr: 'Course sur route ou tapis.',
    AppLang.de: 'Laufen auf der Straße oder dem Laufband.',
    AppLang.it: 'Corsa su strada o tapis roulant.',
    AppLang.pt: 'Corrida na rua ou passadeira.',
  },
  'activity_trail': {
    AppLang.en: 'Trekking',
    AppLang.es: 'Senderismo',
    AppLang.fr: 'Randonnée',
    AppLang.de: 'Trekking',
    AppLang.it: 'Trekking',
    AppLang.pt: 'Trekking',
  },
  'activity_trail_desc': {
    AppLang.en: 'Trail hiking or off-road running.',
    AppLang.es: 'Senderismo o carrera por montaña.',
    AppLang.fr: 'Randonnée ou course en sentier.',
    AppLang.de: 'Wandern oder Trailrunning.',
    AppLang.it: 'Escursionismo o corsa su sentiero.',
    AppLang.pt: 'Caminhada ou corrida em trilho.',
  },
  // ── Bluetooth ──
  'side_right': {
    AppLang.en: 'Right',
    AppLang.es: 'Derecha',
    AppLang.fr: 'Droite',
    AppLang.de: 'Rechts',
    AppLang.it: 'Destra',
    AppLang.pt: 'Direita',
  },
  'side_left': {
    AppLang.en: 'Left',
    AppLang.es: 'Izquierda',
    AppLang.fr: 'Gauche',
    AppLang.de: 'Links',
    AppLang.it: 'Sinistra',
    AppLang.pt: 'Esquerda',
  },
  'insole_right': {
    AppLang.en: 'Right insole',
    AppLang.es: 'Plantilla derecha',
    AppLang.fr: 'Semelle droite',
    AppLang.de: 'Rechte Sohle',
    AppLang.it: 'Soletta destra',
    AppLang.pt: 'Palmilha direita',
  },
  'insole_left': {
    AppLang.en: 'Left insole',
    AppLang.es: 'Plantilla izquierda',
    AppLang.fr: 'Semelle gauche',
    AppLang.de: 'Linke Sohle',
    AppLang.it: 'Soletta sinistra',
    AppLang.pt: 'Palmilha esquerda',
  },
  'status_connected': {
    AppLang.en: 'Connected',
    AppLang.es: 'Conectado',
    AppLang.fr: 'Connecté',
    AppLang.de: 'Verbunden',
    AppLang.it: 'Connesso',
    AppLang.pt: 'Ligado',
  },
  'status_searching': {
    AppLang.en: 'Searching...',
    AppLang.es: 'Buscando...',
    AppLang.fr: 'Recherche...',
    AppLang.de: 'Suche...',
    AppLang.it: 'Ricerca...',
    AppLang.pt: 'A procurar...',
  },
  'status_not_found': {
    AppLang.en: 'Not found',
    AppLang.es: 'No encontrado',
    AppLang.fr: 'Introuvable',
    AppLang.de: 'Nicht gefunden',
    AppLang.it: 'Non trovato',
    AppLang.pt: 'Não encontrado',
  },
  'status_not_connected': {
    AppLang.en: 'Not connected',
    AppLang.es: 'Sin conectar',
    AppLang.fr: 'Non connecté',
    AppLang.de: 'Nicht verbunden',
    AppLang.it: 'Non connesso',
    AppLang.pt: 'Não ligado',
  },
  'device_connection': {
    AppLang.en: 'Device Connection',
    AppLang.es: 'Conexión de dispositivos',
    AppLang.fr: 'Connexion de l\'appareil',
    AppLang.de: 'Geräteverbindung',
    AppLang.it: 'Connessione dispositivo',
    AppLang.pt: 'Ligação de dispositivos',
  },
  'enable_bluetooth': {
    AppLang.en: 'Enable Bluetooth',
    AppLang.es: 'Activar Bluetooth',
    AppLang.fr: 'Activer le Bluetooth',
    AppLang.de: 'Bluetooth aktivieren',
    AppLang.it: 'Attiva Bluetooth',
    AppLang.pt: 'Ativar Bluetooth',
  },
  'bluetooth_required': {
    AppLang.en: 'Bluetooth is required to connect with your smart insoles',
    AppLang.es: 'Se necesita Bluetooth para conectar con tus plantillas inteligentes',
    AppLang.fr: 'Le Bluetooth est nécessaire pour se connecter à vos semelles intelligentes',
    AppLang.de: 'Bluetooth wird benötigt, um sich mit deinen Smart-Einlegesohlen zu verbinden',
    AppLang.it: 'Il Bluetooth è necessario per connettersi alle solette intelligenti',
    AppLang.pt: 'É necessário Bluetooth para ligar às suas palmilhas inteligentes',
  },
  'about_insoles_title': {
    AppLang.en: 'About GOGAIT Smart Insoles',
    AppLang.es: 'Sobre las plantillas inteligentes GOGAIT',
    AppLang.fr: 'À propos des semelles intelligentes GOGAIT',
    AppLang.de: 'Über die GOGAIT Smart-Einlegesohlen',
    AppLang.it: 'Informazioni sulle solette intelligenti GOGAIT',
    AppLang.pt: 'Sobre as palmilhas inteligentes GOGAIT',
  },
  'why_xiao_sensors': {
    AppLang.en: 'Xiao nRF52-based Bluetooth pressure sensors, one per foot',
    AppLang.es: 'Sensores de presión Bluetooth basados en Xiao nRF52, uno por pie',
    AppLang.fr: 'Capteurs de pression Bluetooth basés sur Xiao nRF52, un par pied',
    AppLang.de: 'Bluetooth-Drucksensoren auf Xiao-nRF52-Basis, einer pro Fuß',
    AppLang.it: 'Sensori di pressione Bluetooth basati su Xiao nRF52, uno per piede',
    AppLang.pt: 'Sensores de pressão Bluetooth baseados em Xiao nRF52, um por pé',
  },
  'why_measures_plantar': {
    AppLang.en: 'Measures plantar pressure in real time',
    AppLang.es: 'Mide la presión plantar en tiempo real',
    AppLang.fr: 'Mesure la pression plantaire en temps réel',
    AppLang.de: 'Misst den Fußsohlendruck in Echtzeit',
    AppLang.it: 'Misura la pressione plantare in tempo reale',
    AppLang.pt: 'Mede a pressão plantar em tempo real',
  },
  'why_sends_10ms': {
    AppLang.en: 'Sends heel and metatarsal data every 10ms',
    AppLang.es: 'Envía datos de talón y metatarso cada 10ms',
    AppLang.fr: 'Envoie les données du talon et du métatarse toutes les 10ms',
    AppLang.de: 'Sendet Fersen- und Mittelfußdaten alle 10ms',
    AppLang.it: 'Invia i dati di tallone e metatarso ogni 10ms',
    AppLang.pt: 'Envia dados do calcanhar e metatarso a cada 10ms',
  },
  'why_powers_analysis': {
    AppLang.en: 'Powers the biomechanical gait analysis',
    AppLang.es: 'Impulsa el análisis biomecánico de la marcha',
    AppLang.fr: "Alimente l'analyse biomécanique de la démarche",
    AppLang.de: 'Treibt die biomechanische Ganganalyse an',
    AppLang.it: "Alimenta l'analisi biomeccanica dell'andatura",
    AppLang.pt: 'Alimenta a análise biomecânica da marcha',
  },
  'why_measures_heel_metatarsal': {
    AppLang.en: 'Measures heel and metatarsal pressure',
    AppLang.es: 'Mide la presión de talón y metatarso',
    AppLang.fr: 'Mesure la pression du talon et du métatarse',
    AppLang.de: 'Misst den Fersen- und Mittelfußdruck',
    AppLang.it: 'Misura la pressione di tallone e metatarso',
    AppLang.pt: 'Mede a pressão do calcanhar e metatarso',
  },
  'why_sends_ble': {
    AppLang.en: 'Sends data every 10ms via BLE',
    AppLang.es: 'Envía datos cada 10ms vía BLE',
    AppLang.fr: 'Envoie les données toutes les 10ms via BLE',
    AppLang.de: 'Sendet Daten alle 10ms über BLE',
    AppLang.it: 'Invia dati ogni 10ms via BLE',
    AppLang.pt: 'Envia dados a cada 10ms via BLE',
  },
  'why_powers_heatmap': {
    AppLang.en: 'Powers real-time heatmap analysis',
    AppLang.es: 'Impulsa el análisis del mapa de calor en tiempo real',
    AppLang.fr: 'Alimente l\'analyse de la carte thermique en temps réel',
    AppLang.de: 'Treibt die Echtzeit-Heatmap-Analyse an',
    AppLang.it: 'Alimenta l\'analisi della mappa di calore in tempo reale',
    AppLang.pt: 'Alimenta a análise do mapa de calor em tempo real',
  },
  'connect_smart_insoles': {
    AppLang.en: 'Connect Smart Insoles',
    AppLang.es: 'Conectar plantillas inteligentes',
    AppLang.fr: 'Connecter les semelles intelligentes',
    AppLang.de: 'Smart-Einlegesohlen verbinden',
    AppLang.it: 'Connetti le solette intelligenti',
    AppLang.pt: 'Ligar palmilhas inteligentes',
  },
  'right_left_insoles': {
    AppLang.en: 'Right + left GOGAIT Xiao insoles',
    AppLang.es: 'Plantillas GOGAIT Xiao derecha + izquierda',
    AppLang.fr: 'Semelles GOGAIT Xiao droite + gauche',
    AppLang.de: 'Rechte + linke GOGAIT-Xiao-Sohlen',
    AppLang.it: 'Solette GOGAIT Xiao destra + sinistra',
    AppLang.pt: 'Palmilhas GOGAIT Xiao direita + esquerda',
  },
  'connect_devices': {
    AppLang.en: 'Connect Devices',
    AppLang.es: 'Conectar dispositivos',
    AppLang.fr: 'Connecter les appareils',
    AppLang.de: 'Geräte verbinden',
    AppLang.it: 'Connetti dispositivi',
    AppLang.pt: 'Ligar dispositivos',
  },
  'searching_for_insoles': {
    AppLang.en: 'Searching for insoles...',
    AppLang.es: 'Buscando plantillas...',
    AppLang.fr: 'Recherche de semelles...',
    AppLang.de: 'Suche nach Sohlen...',
    AppLang.it: 'Ricerca solette...',
    AppLang.pt: 'A procurar palmilhas...',
  },
  'waiting_up_to_12s': {
    AppLang.en: 'Waiting up to 12 seconds',
    AppLang.es: 'Esperando hasta 12 segundos',
    AppLang.fr: "Attente jusqu'à 12 secondes",
    AppLang.de: 'Warte bis zu 12 Sekunden',
    AppLang.it: 'Attesa fino a 12 secondi',
    AppLang.pt: 'A aguardar até 12 segundos',
  },
  'both_insoles_connected': {
    AppLang.en: 'Both insoles connected!',
    AppLang.es: '¡Ambas plantillas conectadas!',
    AppLang.fr: 'Les deux semelles sont connectées !',
    AppLang.de: 'Beide Sohlen verbunden!',
    AppLang.it: 'Entrambe le solette connesse!',
    AppLang.pt: 'Ambas as palmilhas ligadas!',
  },
  'partially_connected': {
    AppLang.en: 'Partially connected',
    AppLang.es: 'Conectado parcialmente',
    AppLang.fr: 'Partiellement connecté',
    AppLang.de: 'Teilweise verbunden',
    AppLang.it: 'Parzialmente connesso',
    AppLang.pt: 'Parcialmente ligado',
  },
  'both_ready': {
    AppLang.en: 'Right and left smart insoles ready for analysis',
    AppLang.es: 'Plantillas inteligentes derecha e izquierda listas para el análisis',
    AppLang.fr: 'Semelles intelligentes droite et gauche prêtes pour l\'analyse',
    AppLang.de: 'Rechte und linke Smart-Einlegesohlen bereit für die Analyse',
    AppLang.it: 'Solette intelligenti destra e sinistra pronte per l\'analisi',
    AppLang.pt: 'Palmilhas inteligentes direita e esquerda prontas para a análise',
  },
  'missing_insole': {
    AppLang.en: 'Missing the {side} insole — you can search again or continue with just one',
    AppLang.es: 'Falta la plantilla {side} — puedes buscar de nuevo o continuar con solo una',
    AppLang.fr: 'Il manque la semelle {side} — vous pouvez rechercher à nouveau ou continuer avec une seule',
    AppLang.de: 'Die {side} Sohle fehlt — du kannst erneut suchen oder mit nur einer fortfahren',
    AppLang.it: 'Manca la soletta {side} — puoi cercare di nuovo o continuare con una sola',
    AppLang.pt: 'Falta a palmilha {side} — pode procurar novamente ou continuar com apenas uma',
  },
  'search_again': {
    AppLang.en: 'Search again',
    AppLang.es: 'Buscar de nuevo',
    AppLang.fr: 'Rechercher à nouveau',
    AppLang.de: 'Erneut suchen',
    AppLang.it: 'Cerca di nuovo',
    AppLang.pt: 'Procurar novamente',
  },
  'continue_label': {
    AppLang.en: 'Continue',
    AppLang.es: 'Continuar',
    AppLang.fr: 'Continuer',
    AppLang.de: 'Weiter',
    AppLang.it: 'Continua',
    AppLang.pt: 'Continuar',
  },
  'connection_failed': {
    AppLang.en: 'Connection Failed',
    AppLang.es: 'Conexión fallida',
    AppLang.fr: 'Échec de la connexion',
    AppLang.de: 'Verbindung fehlgeschlagen',
    AppLang.it: 'Connessione fallita',
    AppLang.pt: 'Falha na ligação',
  },
  'could_not_find_insoles': {
    AppLang.en: 'Could not find the insole(s).\nMake sure they are powered on and nearby.',
    AppLang.es: 'No se encontraron las plantillas.\nAsegúrate de que estén encendidas y cerca.',
    AppLang.fr: 'Semelle(s) introuvable(s).\nAssurez-vous qu\'elles sont allumées et à proximité.',
    AppLang.de: 'Sohle(n) nicht gefunden.\nStelle sicher, dass sie eingeschaltet und in der Nähe sind.',
    AppLang.it: 'Impossibile trovare le solette.\nAssicurati che siano accese e vicine.',
    AppLang.pt: 'Não foi possível encontrar as palmilhas.\nCertifique-se de que estão ligadas e próximas.',
  },
  'retry': {
    AppLang.en: 'Retry',
    AppLang.es: 'Reintentar',
    AppLang.fr: 'Réessayer',
    AppLang.de: 'Erneut versuchen',
    AppLang.it: 'Riprova',
    AppLang.pt: 'Tentar novamente',
  },
  'continue_with_1_insole': {
    AppLang.en: 'Continue with 1 insole',
    AppLang.es: 'Continuar con 1 plantilla',
    AppLang.fr: 'Continuer avec 1 semelle',
    AppLang.de: 'Mit 1 Sohle fortfahren',
    AppLang.it: 'Continua con 1 soletta',
    AppLang.pt: 'Continuar com 1 palmilha',
  },
  // ── Preparación / calibración ──
  'insole_side_connected': {
    AppLang.en: '{side} insole connected',
    AppLang.es: 'Plantilla {side} conectada',
    AppLang.fr: 'Semelle {side} connectée',
    AppLang.de: '{side} Sohle verbunden',
    AppLang.it: 'Soletta {side} connessa',
    AppLang.pt: 'Palmilha {side} ligada',
  },
  'disconnected': {
    AppLang.en: 'Disconnected',
    AppLang.es: 'Desconectado',
    AppLang.fr: 'Déconnecté',
    AppLang.de: 'Getrennt',
    AppLang.it: 'Disconnesso',
    AppLang.pt: 'Desligado',
  },
  'searching_device': {
    AppLang.en: 'Searching {name}...',
    AppLang.es: 'Buscando {name}...',
    AppLang.fr: 'Recherche de {name}...',
    AppLang.de: 'Suche {name}...',
    AppLang.it: 'Ricerca {name}...',
    AppLang.pt: 'A procurar {name}...',
  },
  'insole_not_found': {
    AppLang.en: 'Insole not found',
    AppLang.es: 'Plantilla no encontrada',
    AppLang.fr: 'Semelle introuvable',
    AppLang.de: 'Sohle nicht gefunden',
    AppLang.it: 'Soletta non trovata',
    AppLang.pt: 'Palmilha não encontrada',
  },
  'err_no_data_insole': {
    AppLang.en: 'No data received from the insole.',
    AppLang.es: 'No se han recibido datos de la plantilla.',
    AppLang.fr: "Aucune donnée reçue de la semelle.",
    AppLang.de: 'Keine Daten von der Sohle empfangen.',
    AppLang.it: 'Nessun dato ricevuto dalla soletta.',
    AppLang.pt: 'Não foram recebidos dados da palmilha.',
  },
  'err_not_enough_difference': {
    AppLang.en: 'Not enough difference detected. Press harder and repeat this step.',
    AppLang.es: 'No se detecta suficiente diferencia. Presiona más fuerte y repite este paso.',
    AppLang.fr: 'Différence insuffisante détectée. Appuyez plus fort et répétez cette étape.',
    AppLang.de: 'Zu geringer Unterschied erkannt. Drücke fester und wiederhole diesen Schritt.',
    AppLang.it: 'Differenza insufficiente rilevata. Premi più forte e ripeti questo passo.',
    AppLang.pt: 'Diferença insuficiente detetada. Pressione com mais força e repita este passo.',
  },
  'phase_pressure_lift': {
    AppLang.en: 'Pressure detected, lift your foot',
    AppLang.es: 'Presión detectada, levanta el pie',
    AppLang.fr: 'Pression détectée, levez le pied',
    AppLang.de: 'Druck erkannt, hebe den Fuß',
    AppLang.it: 'Pressione rilevata, solleva il piede',
    AppLang.pt: 'Pressão detetada, levante o pé',
  },
  'phase_foot_lifted': {
    AppLang.en: 'Foot lifted',
    AppLang.es: 'Pie levantado',
    AppLang.fr: 'Pied levé',
    AppLang.de: 'Fuß angehoben',
    AppLang.it: 'Piede sollevato',
    AppLang.pt: 'Pé levantado',
  },
  'phase_full_foot_pressed': {
    AppLang.en: 'Full foot pressed',
    AppLang.es: 'Pie completo presionado',
    AppLang.fr: 'Pied entier pressé',
    AppLang.de: 'Ganzer Fuß gedrückt',
    AppLang.it: 'Piede intero premuto',
    AppLang.pt: 'Pé inteiro pressionado',
  },
  'phase_waiting_full_foot': {
    AppLang.en: 'Waiting for full-foot contact...',
    AppLang.es: 'Esperando contacto de pie completo...',
    AppLang.fr: 'En attente du contact du pied entier...',
    AppLang.de: 'Warte auf Kontakt des ganzen Fußes...',
    AppLang.it: "In attesa del contatto dell'intero piede...",
    AppLang.pt: 'A aguardar contacto do pé inteiro...',
  },
  'phase_heel_pressed': {
    AppLang.en: 'Heel pressed',
    AppLang.es: 'Talón presionado',
    AppLang.fr: 'Talon pressé',
    AppLang.de: 'Ferse gedrückt',
    AppLang.it: 'Tallone premuto',
    AppLang.pt: 'Calcanhar pressionado',
  },
  'phase_waiting_heel': {
    AppLang.en: 'Waiting for heel contact...',
    AppLang.es: 'Esperando contacto de talón...',
    AppLang.fr: 'En attente du contact du talon...',
    AppLang.de: 'Warte auf Fersenkontakt...',
    AppLang.it: 'In attesa del contatto del tallone...',
    AppLang.pt: 'A aguardar contacto do calcanhar...',
  },
  'phase_forefoot_pressed': {
    AppLang.en: 'Forefoot pressed',
    AppLang.es: 'Metatarso presionado',
    AppLang.fr: 'Avant-pied pressé',
    AppLang.de: 'Vorfuß gedrückt',
    AppLang.it: 'Avampiede premuto',
    AppLang.pt: 'Metatarso pressionado',
  },
  'phase_waiting_forefoot': {
    AppLang.en: 'Waiting for forefoot contact...',
    AppLang.es: 'Esperando contacto de metatarso...',
    AppLang.fr: "En attente du contact de l'avant-pied...",
    AppLang.de: 'Warte auf Vorfußkontakt...',
    AppLang.it: "In attesa del contatto dell'avampiede...",
    AppLang.pt: 'A aguardar contacto do metatarso...',
  },
  'phase_calibration_complete': {
    AppLang.en: 'Calibration complete',
    AppLang.es: 'Calibración completa',
    AppLang.fr: 'Étalonnage terminé',
    AppLang.de: 'Kalibrierung abgeschlossen',
    AppLang.it: 'Calibrazione completata',
    AppLang.pt: 'Calibração concluída',
  },
  'phase_hop_detected': {
    AppLang.en: 'Hop detected',
    AppLang.es: 'Salto detectado',
    AppLang.fr: 'Saut détecté',
    AppLang.de: 'Sprung erkannt',
    AppLang.it: 'Salto rilevato',
    AppLang.pt: 'Salto detetado',
  },
  'phase_waiting_hop': {
    AppLang.en: 'Waiting for the hop...',
    AppLang.es: 'Esperando el salto...',
    AppLang.fr: 'En attente du saut...',
    AppLang.de: 'Warte auf den Sprung...',
    AppLang.it: 'In attesa del salto...',
    AppLang.pt: 'A aguardar o salto...',
  },
  'phase_waiting_heel_hop': {
    AppLang.en: 'Waiting for the heel hop...',
    AppLang.es: 'Esperando el salto de talón...',
    AppLang.fr: 'En attente du saut sur le talon...',
    AppLang.de: 'Warte auf den Fersensprung...',
    AppLang.it: 'In attesa del salto sul tallone...',
    AppLang.pt: 'A aguardar o salto no calcanhar...',
  },
  'phase_waiting_forefoot_hop': {
    AppLang.en: 'Waiting for the forefoot hop...',
    AppLang.es: 'Esperando el salto de metatarso...',
    AppLang.fr: "En attente du saut sur l'avant-pied...",
    AppLang.de: 'Warte auf den Vorfußsprung...',
    AppLang.it: "In attesa del salto sull'avampiede...",
    AppLang.pt: 'A aguardar o salto no metatarso...',
  },
  'prepare_insole': {
    AppLang.en: 'Prepare your insole',
    AppLang.es: 'Prepara tu plantilla',
    AppLang.fr: 'Préparez votre semelle',
    AppLang.de: 'Bereite deine Sohle vor',
    AppLang.it: 'Prepara la tua soletta',
    AppLang.pt: 'Prepare a sua palmilha',
  },
  'prepare_insole_desc': {
    AppLang.en: 'You need to do this every time you put on the insoles, so the pressure reading matches your weight and each sensor.',
    AppLang.es: 'Tienes que hacer esto cada vez que te pones las plantillas, para que la lectura de presión coincida con tu peso y cada sensor.',
    AppLang.fr: 'Vous devez le faire à chaque fois que vous mettez les semelles, pour que la lecture de pression corresponde à votre poids et à chaque capteur.',
    AppLang.de: 'Das musst du jedes Mal machen, wenn du die Sohlen anziehst, damit die Druckmessung zu deinem Gewicht und jedem Sensor passt.',
    AppLang.it: 'Devi farlo ogni volta che indossi le solette, così la lettura della pressione corrisponde al tuo peso e a ogni sensore.',
    AppLang.pt: 'Tem de fazer isto sempre que calçar as palmilhas, para que a leitura de pressão corresponda ao seu peso e a cada sensor.',
  },
  'calibrating_foot': {
    AppLang.en: 'Calibrating: {side} foot insole',
    AppLang.es: 'Calibrando: plantilla del pie {side}',
    AppLang.fr: 'Étalonnage : semelle du pied {side}',
    AppLang.de: 'Kalibrierung: {side} Fußsohle',
    AppLang.it: 'Calibrazione: soletta del piede {side}',
    AppLang.pt: 'A calibrar: palmilha do pé {side}',
  },
  'put_on_insole': {
    AppLang.en: 'Put on the insole',
    AppLang.es: 'Ponte la plantilla',
    AppLang.fr: 'Mettez la semelle',
    AppLang.de: 'Zieh die Sohle an',
    AppLang.it: 'Indossa la soletta',
    AppLang.pt: 'Calce a palmilha',
  },
  'fit_snugly': {
    AppLang.en: 'Fit it snugly, with the sensor under the heel area.',
    AppLang.es: 'Ajústala bien, con el sensor bajo la zona del talón.',
    AppLang.fr: 'Ajustez-la bien, avec le capteur sous la zone du talon.',
    AppLang.de: 'Passe sie eng an, mit dem Sensor unter dem Fersenbereich.',
    AppLang.it: 'Indossala bene aderente, con il sensore sotto il tallone.',
    AppLang.pt: 'Ajuste-a bem, com o sensor sob a zona do calcanhar.',
  },
  'connect_via_bluetooth': {
    AppLang.en: 'Connect via Bluetooth',
    AppLang.es: 'Conectar por Bluetooth',
    AppLang.fr: 'Se connecter via Bluetooth',
    AppLang.de: 'Über Bluetooth verbinden',
    AppLang.it: 'Connetti via Bluetooth',
    AppLang.pt: 'Ligar via Bluetooth',
  },
  'connect_button': {
    AppLang.en: 'Connect',
    AppLang.es: 'Conectar',
    AppLang.fr: 'Connecter',
    AppLang.de: 'Verbinden',
    AppLang.it: 'Connetti',
    AppLang.pt: 'Ligar',
  },
  'calibrate_to_weight': {
    AppLang.en: 'Calibrate to your weight',
    AppLang.es: 'Calibrar según tu peso',
    AppLang.fr: 'Étalonner selon votre poids',
    AppLang.de: 'Auf dein Gewicht kalibrieren',
    AppLang.it: 'Calibra in base al tuo peso',
    AppLang.pt: 'Calibrar de acordo com o seu peso',
  },
  'heatmap_pending': {
    AppLang.en: 'The heat map will appear after capturing the rest and full-load reference steps.',
    AppLang.es: 'El mapa de calor aparecerá tras capturar los pasos de referencia de reposo y carga completa.',
    AppLang.fr: 'La carte thermique apparaîtra après la capture des étapes de référence repos et charge complète.',
    AppLang.de: 'Die Heatmap erscheint nach der Erfassung der Referenzschritte Ruhe und Volllast.',
    AppLang.it: 'La mappa di calore apparirà dopo aver acquisito i passaggi di riferimento riposo e carico completo.',
    AppLang.pt: 'O mapa de calor aparecerá após capturar os passos de referência de repouso e carga total.',
  },
  'raw_adc': {
    AppLang.en: 'Raw ADC: {n} / 4095',
    AppLang.es: 'ADC bruto: {n} / 4095',
    AppLang.fr: 'ADC brut : {n} / 4095',
    AppLang.de: 'Roh-ADC: {n} / 4095',
    AppLang.it: 'ADC grezzo: {n} / 4095',
    AppLang.pt: 'ADC bruto: {n} / 4095',
  },
  'restart_calibration_foot': {
    AppLang.en: 'Restart calibration for this foot',
    AppLang.es: 'Reiniciar calibración de este pie',
    AppLang.fr: 'Redémarrer l\'étalonnage de ce pied',
    AppLang.de: 'Kalibrierung für diesen Fuß neu starten',
    AppLang.it: 'Riavvia la calibrazione di questo piede',
    AppLang.pt: 'Reiniciar calibração deste pé',
  },
  'substep_no_pressure': {
    AppLang.en: 'No pressure, lift your foot',
    AppLang.es: 'Sin presión, levanta el pie',
    AppLang.fr: 'Sans pression, levez le pied',
    AppLang.de: 'Kein Druck, hebe den Fuß',
    AppLang.it: 'Nessuna pressione, solleva il piede',
    AppLang.pt: 'Sem pressão, levante o pé',
  },
  'substep_full_pressure': {
    AppLang.en: 'Full pressure, put your full weight down',
    AppLang.es: 'Presión completa, apoya todo tu peso',
    AppLang.fr: 'Pression complète, posez tout votre poids',
    AppLang.de: 'Voller Druck, lege dein ganzes Gewicht auf',
    AppLang.it: 'Pressione completa, appoggia tutto il peso',
    AppLang.pt: 'Pressão total, apoie todo o seu peso',
  },
  'substep_hop': {
    AppLang.en: 'Hop, jump on this foot and land on the insole',
    AppLang.es: 'Salto, salta con este pie y aterriza sobre la plantilla',
    AppLang.fr: 'Saut, sautez sur ce pied et atterrissez sur la semelle',
    AppLang.de: 'Sprung, springe auf diesem Fuß und lande auf der Sohle',
    AppLang.it: 'Salto, salta su questo piede e atterra sulla soletta',
    AppLang.pt: 'Salto, salte com este pé e aterre na palmilha',
  },
  'substep_heel_only': {
    AppLang.en: 'Heel only, lift the front of your foot',
    AppLang.es: 'Solo talón, levanta la parte delantera del pie',
    AppLang.fr: "Talon seulement, levez l'avant du pied",
    AppLang.de: 'Nur Ferse, hebe den vorderen Teil des Fußes',
    AppLang.it: 'Solo tallone, solleva la parte anteriore del piede',
    AppLang.pt: 'Só calcanhar, levante a parte da frente do pé',
  },
  'substep_heel_hop': {
    AppLang.en: 'Heel hop, jump and land on your heel',
    AppLang.es: 'Salto de talón, salta y aterriza sobre el talón',
    AppLang.fr: 'Saut sur le talon, sautez et atterrissez sur le talon',
    AppLang.de: 'Fersensprung, springe und lande auf der Ferse',
    AppLang.it: 'Salto sul tallone, salta e atterra sul tallone',
    AppLang.pt: 'Salto no calcanhar, salte e aterre no calcanhar',
  },
  'substep_forefoot_only': {
    AppLang.en: 'Forefoot only, lift your heel',
    AppLang.es: 'Solo metatarso, levanta el talón',
    AppLang.fr: "Avant-pied seulement, levez le talon",
    AppLang.de: 'Nur Vorfuß, hebe die Ferse',
    AppLang.it: 'Solo avampiede, solleva il tallone',
    AppLang.pt: 'Só metatarso, levante o calcanhar',
  },
  'substep_forefoot_hop': {
    AppLang.en: 'Forefoot hop, jump and land on your toes',
    AppLang.es: 'Salto de metatarso, salta y aterriza sobre la punta',
    AppLang.fr: "Saut sur l'avant-pied, sautez et atterrissez sur la pointe des pieds",
    AppLang.de: 'Vorfußsprung, springe und lande auf den Zehen',
    AppLang.it: "Salto sull'avampiede, salta e atterra sulle punte",
    AppLang.pt: 'Salto no metatarso, salte e aterre na ponta dos pés',
  },
  'right_foot_calibrated': {
    AppLang.en: 'Right foot calibrated! Now let\'s calibrate the left foot...',
    AppLang.es: '¡Pie derecho calibrado! Ahora calibremos el pie izquierdo...',
    AppLang.fr: 'Pied droit étalonné ! Passons maintenant au pied gauche...',
    AppLang.de: 'Rechter Fuß kalibriert! Jetzt kalibrieren wir den linken Fuß...',
    AppLang.it: 'Piede destro calibrato! Ora calibriamo il piede sinistro...',
    AppLang.pt: 'Pé direito calibrado! Agora vamos calibrar o pé esquerdo...',
  },
  'calibrated_entering_live': {
    AppLang.en: 'Calibrated. Entering Live Analysis...',
    AppLang.es: 'Calibrado. Entrando en Live Analysis...',
    AppLang.fr: "Étalonné. Entrée dans l'analyse en direct...",
    AppLang.de: 'Kalibriert. Live-Analyse wird gestartet...',
    AppLang.it: "Calibrato. Ingresso nell'analisi live...",
    AppLang.pt: 'Calibrado. A entrar na Análise ao Vivo...',
  },
  'capture_button': {
    AppLang.en: 'Capture',
    AppLang.es: 'Capturar',
    AppLang.fr: 'Capturer',
    AppLang.de: 'Erfassen',
    AppLang.it: 'Cattura',
    AppLang.pt: 'Capturar',
  },
  'redo_button': {
    AppLang.en: 'Redo',
    AppLang.es: 'Repetir',
    AppLang.fr: 'Refaire',
    AppLang.de: 'Wiederholen',
    AppLang.it: 'Ripeti',
    AppLang.pt: 'Refazer',
  },
  // ── Actividad en vivo (Live Analysis) ──
  'live_analysis': {
    AppLang.en: 'Live Analysis',
    AppLang.es: 'Análisis en vivo',
    AppLang.fr: 'Analyse en direct',
    AppLang.de: 'Live-Analyse',
    AppLang.it: 'Analisi live',
    AppLang.pt: 'Análise ao vivo',
  },
  'ble_half_connected': {
    AppLang.en: '1/2 Connected',
    AppLang.es: '1/2 conectado',
    AppLang.fr: '1/2 connecté',
    AppLang.de: '1/2 verbunden',
    AppLang.it: '1/2 connesso',
    AppLang.pt: '1/2 ligado',
  },
  'searching_short': {
    AppLang.en: 'Searching',
    AppLang.es: 'Buscando',
    AppLang.fr: 'Recherche',
    AppLang.de: 'Suche',
    AppLang.it: 'Ricerca',
    AppLang.pt: 'A procurar',
  },
  'session_duration': {
    AppLang.en: 'Session Duration',
    AppLang.es: 'Duración de la sesión',
    AppLang.fr: 'Durée de la session',
    AppLang.de: 'Sitzungsdauer',
    AppLang.it: 'Durata della sessione',
    AppLang.pt: 'Duração da sessão',
  },
  'gait_phase_heel_strike': {
    AppLang.en: 'Heel Strike',
    AppLang.es: 'Contacto de talón',
    AppLang.fr: 'Attaque du talon',
    AppLang.de: 'Fersenkontakt',
    AppLang.it: 'Contatto del tallone',
    AppLang.pt: 'Contacto do calcanhar',
  },
  'gait_phase_midstance': {
    AppLang.en: 'Midstance',
    AppLang.es: 'Apoyo medio',
    AppLang.fr: 'Appui intermédiaire',
    AppLang.de: 'Mittelstand',
    AppLang.it: 'Appoggio intermedio',
    AppLang.pt: 'Apoio médio',
  },
  'gait_phase_propulsion': {
    AppLang.en: 'Propulsion',
    AppLang.es: 'Propulsión',
    AppLang.fr: 'Propulsion',
    AppLang.de: 'Abstoß',
    AppLang.it: 'Propulsione',
    AppLang.pt: 'Propulsão',
  },
  'gait_phase_swing': {
    AppLang.en: 'Swing',
    AppLang.es: 'Balanceo',
    AppLang.fr: 'Oscillation',
    AppLang.de: 'Schwungphase',
    AppLang.it: 'Oscillazione',
    AppLang.pt: 'Balanço',
  },
  'plantar_pressure': {
    AppLang.en: 'Plantar Pressure',
    AppLang.es: 'Presión plantar',
    AppLang.fr: 'Pression plantaire',
    AppLang.de: 'Fußsohlendruck',
    AppLang.it: 'Pressione plantare',
    AppLang.pt: 'Pressão plantar',
  },
  'left_foot': {
    AppLang.en: 'Left Foot',
    AppLang.es: 'Pie izquierdo',
    AppLang.fr: 'Pied gauche',
    AppLang.de: 'Linker Fuß',
    AppLang.it: 'Piede sinistro',
    AppLang.pt: 'Pé esquerdo',
  },
  'right_foot': {
    AppLang.en: 'Right Foot',
    AppLang.es: 'Pie derecho',
    AppLang.fr: 'Pied droit',
    AppLang.de: 'Rechter Fuß',
    AppLang.it: 'Piede destro',
    AppLang.pt: 'Pé direito',
  },
  'pressure_level': {
    AppLang.en: 'Pressure Level',
    AppLang.es: 'Nivel de presión',
    AppLang.fr: 'Niveau de pression',
    AppLang.de: 'Druckstufe',
    AppLang.it: 'Livello di pressione',
    AppLang.pt: 'Nível de pressão',
  },
  'low_label': {
    AppLang.en: 'Low ',
    AppLang.es: 'Bajo ',
    AppLang.fr: 'Faible ',
    AppLang.de: 'Niedrig ',
    AppLang.it: 'Basso ',
    AppLang.pt: 'Baixo ',
  },
  'metric_distance': {
    AppLang.en: 'Distance',
    AppLang.es: 'Distancia',
    AppLang.fr: 'Distance',
    AppLang.de: 'Distanz',
    AppLang.it: 'Distanza',
    AppLang.pt: 'Distância',
  },
  'resume_button': {
    AppLang.en: 'Resume',
    AppLang.es: 'Reanudar',
    AppLang.fr: 'Reprendre',
    AppLang.de: 'Fortsetzen',
    AppLang.it: 'Riprendi',
    AppLang.pt: 'Retomar',
  },
  'pause_button': {
    AppLang.en: 'Pause',
    AppLang.es: 'Pausar',
    AppLang.fr: 'Pause',
    AppLang.de: 'Pause',
    AppLang.it: 'Pausa',
    AppLang.pt: 'Pausar',
  },
  'start_button': {
    AppLang.en: 'Start',
    AppLang.es: 'Empezar',
    AppLang.fr: 'Démarrer',
    AppLang.de: 'Start',
    AppLang.it: 'Avvia',
    AppLang.pt: 'Iniciar',
  },
  'finish_button': {
    AppLang.en: 'Finish',
    AppLang.es: 'Finalizar',
    AppLang.fr: 'Terminer',
    AppLang.de: 'Beenden',
    AppLang.it: 'Termina',
    AppLang.pt: 'Terminar',
  },
  'recording_in_progress': {
    AppLang.en: 'Recording in progress',
    AppLang.es: 'Grabación en curso',
    AppLang.fr: 'Enregistrement en cours',
    AppLang.de: 'Aufnahme läuft',
    AppLang.it: 'Registrazione in corso',
    AppLang.pt: 'Gravação em curso',
  },
  'finish_activity_title': {
    AppLang.en: 'Finish activity?',
    AppLang.es: '¿Finalizar actividad?',
    AppLang.fr: "Terminer l'activité ?",
    AppLang.de: 'Aktivität beenden?',
    AppLang.it: "Terminare l'attività?",
    AppLang.pt: 'Terminar atividade?',
  },
  'finish_activity_msg': {
    AppLang.en: 'Do you want to finish and save this activity?',
    AppLang.es: '¿Quieres finalizar y guardar esta actividad?',
    AppLang.fr: 'Voulez-vous terminer et enregistrer cette activité ?',
    AppLang.de: 'Möchtest du diese Aktivität beenden und speichern?',
    AppLang.it: 'Vuoi terminare e salvare questa attività?',
    AppLang.pt: 'Quer terminar e guardar esta atividade?',
  },
  'cancel_button': {
    AppLang.en: 'Cancel',
    AppLang.es: 'Cancelar',
    AppLang.fr: 'Annuler',
    AppLang.de: 'Abbrechen',
    AppLang.it: 'Annulla',
    AppLang.pt: 'Cancelar',
  },
  // ── Resumen de sesión ──
  'time_night': {
    AppLang.en: 'Night',
    AppLang.es: 'Noche',
    AppLang.fr: 'Nuit',
    AppLang.de: 'Nacht',
    AppLang.it: 'Notte',
    AppLang.pt: 'Noite',
  },
  'time_morning': {
    AppLang.en: 'Morning',
    AppLang.es: 'Mañana',
    AppLang.fr: 'Matin',
    AppLang.de: 'Morgen',
    AppLang.it: 'Mattina',
    AppLang.pt: 'Manhã',
  },
  'time_afternoon': {
    AppLang.en: 'Afternoon',
    AppLang.es: 'Tarde',
    AppLang.fr: 'Après-midi',
    AppLang.de: 'Nachmittag',
    AppLang.it: 'Pomeriggio',
    AppLang.pt: 'Tarde',
  },
  'time_evening': {
    AppLang.en: 'Evening',
    AppLang.es: 'Noche',
    AppLang.fr: 'Soir',
    AppLang.de: 'Abend',
    AppLang.it: 'Sera',
    AppLang.pt: 'Noitinha',
  },
  'trail_run': {
    AppLang.en: 'Trail Run',
    AppLang.es: 'Trail',
    AppLang.fr: 'Trail',
    AppLang.de: 'Trailrun',
    AppLang.it: 'Trail',
    AppLang.pt: 'Trail',
  },
  'session_summary': {
    AppLang.en: 'Session Summary',
    AppLang.es: 'Resumen de la sesión',
    AppLang.fr: 'Résumé de la session',
    AppLang.de: 'Sitzungsübersicht',
    AppLang.it: 'Riepilogo sessione',
    AppLang.pt: 'Resumo da sessão',
  },
  'activity_type': {
    AppLang.en: 'Activity Type',
    AppLang.es: 'Tipo de actividad',
    AppLang.fr: "Type d'activité",
    AppLang.de: 'Aktivitätstyp',
    AppLang.it: 'Tipo di attività',
    AppLang.pt: 'Tipo de atividade',
  },
  'activity_title': {
    AppLang.en: 'Activity Title',
    AppLang.es: 'Título de la actividad',
    AppLang.fr: "Titre de l'activité",
    AppLang.de: 'Aktivitätstitel',
    AppLang.it: 'Titolo attività',
    AppLang.pt: 'Título da atividade',
  },
  'activity_title_hint': {
    AppLang.en: 'Morning Run',
    AppLang.es: 'Carrera matutina',
    AppLang.fr: 'Course matinale',
    AppLang.de: 'Morgenlauf',
    AppLang.it: 'Corsa mattutina',
    AppLang.pt: 'Corrida matinal',
  },
  'notes_optional': {
    AppLang.en: 'Notes (Optional)',
    AppLang.es: 'Notas (opcional)',
    AppLang.fr: 'Notes (facultatif)',
    AppLang.de: 'Notizen (optional)',
    AppLang.it: 'Note (opzionale)',
    AppLang.pt: 'Notas (opcional)',
  },
  'notes_hint': {
    AppLang.en: 'Add any notes about this session...',
    AppLang.es: 'Añade cualquier nota sobre esta sesión...',
    AppLang.fr: 'Ajoutez des notes sur cette session...',
    AppLang.de: 'Füge Notizen zu dieser Sitzung hinzu...',
    AppLang.it: 'Aggiungi note su questa sessione...',
    AppLang.pt: 'Adicione notas sobre esta sessão...',
  },
  'session_performance': {
    AppLang.en: 'Session Performance',
    AppLang.es: 'Rendimiento de la sesión',
    AppLang.fr: 'Performance de la session',
    AppLang.de: 'Sitzungsleistung',
    AppLang.it: 'Prestazione della sessione',
    AppLang.pt: 'Desempenho da sessão',
  },
  'both_feet': {
    AppLang.en: 'Both Feet',
    AppLang.es: 'Ambos pies',
    AppLang.fr: 'Les deux pieds',
    AppLang.de: 'Beide Füße',
    AppLang.it: 'Entrambi i piedi',
    AppLang.pt: 'Ambos os pés',
  },
  'duration_label': {
    AppLang.en: 'Duration',
    AppLang.es: 'Duración',
    AppLang.fr: 'Durée',
    AppLang.de: 'Dauer',
    AppLang.it: 'Durata',
    AppLang.pt: 'Duração',
  },
  'steps_label': {
    AppLang.en: 'Steps',
    AppLang.es: 'Pasos',
    AppLang.fr: 'Pas',
    AppLang.de: 'Schritte',
    AppLang.it: 'Passi',
    AppLang.pt: 'Passos',
  },
  'save_session': {
    AppLang.en: 'Save Session',
    AppLang.es: 'Guardar sesión',
    AppLang.fr: 'Enregistrer la session',
    AppLang.de: 'Sitzung speichern',
    AppLang.it: 'Salva sessione',
    AppLang.pt: 'Guardar sessão',
  },
  // ── Histórico ──
  'activity_history': {
    AppLang.en: 'Activity History',
    AppLang.es: 'Historial de actividad',
    AppLang.fr: "Historique d'activité",
    AppLang.de: 'Aktivitätsverlauf',
    AppLang.it: 'Cronologia attività',
    AppLang.pt: 'Histórico de atividade',
  },
  'hours_label': {
    AppLang.en: 'Hours',
    AppLang.es: 'Horas',
    AppLang.fr: 'Heures',
    AppLang.de: 'Stunden',
    AppLang.it: 'Ore',
    AppLang.pt: 'Horas',
  },
  'sessions_label': {
    AppLang.en: 'Sessions',
    AppLang.es: 'Sesiones',
    AppLang.fr: 'Sessions',
    AppLang.de: 'Sitzungen',
    AppLang.it: 'Sessioni',
    AppLang.pt: 'Sessões',
  },
  'filter_all': {
    AppLang.en: 'All',
    AppLang.es: 'Todas',
    AppLang.fr: 'Toutes',
    AppLang.de: 'Alle',
    AppLang.it: 'Tutte',
    AppLang.pt: 'Todas',
  },
  'filter_walking': {
    AppLang.en: 'Walking',
    AppLang.es: 'Caminar',
    AppLang.fr: 'Marche',
    AppLang.de: 'Gehen',
    AppLang.it: 'Camminata',
    AppLang.pt: 'Caminhada',
  },
  'filter_running': {
    AppLang.en: 'Running',
    AppLang.es: 'Correr',
    AppLang.fr: 'Course',
    AppLang.de: 'Laufen',
    AppLang.it: 'Corsa',
    AppLang.pt: 'Corrida',
  },
  'filter_trail': {
    AppLang.en: 'Trail',
    AppLang.es: 'Trail',
    AppLang.fr: 'Trail',
    AppLang.de: 'Trail',
    AppLang.it: 'Trail',
    AppLang.pt: 'Trail',
  },
  'no_activities_found': {
    AppLang.en: 'No activities found',
    AppLang.es: 'No se encontraron actividades',
    AppLang.fr: 'Aucune activité trouvée',
    AppLang.de: 'Keine Aktivitäten gefunden',
    AppLang.it: 'Nessuna attività trovata',
    AppLang.pt: 'Nenhuma atividade encontrada',
  },
  // ── Exportar métricas ──
  'export_metrics_title': {
    AppLang.en: 'Export Metrics',
    AppLang.es: 'Exportar métricas',
    AppLang.fr: 'Exporter les métriques',
    AppLang.de: 'Metriken exportieren',
    AppLang.it: 'Esporta metriche',
    AppLang.pt: 'Exportar métricas',
  },
  'time_period': {
    AppLang.en: 'Time Period',
    AppLang.es: 'Periodo',
    AppLang.fr: 'Période',
    AppLang.de: 'Zeitraum',
    AppLang.it: 'Periodo',
    AppLang.pt: 'Período',
  },
  'period_week': {
    AppLang.en: 'Week',
    AppLang.es: 'Semana',
    AppLang.fr: 'Semaine',
    AppLang.de: 'Woche',
    AppLang.it: 'Settimana',
    AppLang.pt: 'Semana',
  },
  'period_month': {
    AppLang.en: 'Month',
    AppLang.es: 'Mes',
    AppLang.fr: 'Mois',
    AppLang.de: 'Monat',
    AppLang.it: 'Mese',
    AppLang.pt: 'Mês',
  },
  'period_year': {
    AppLang.en: 'Year',
    AppLang.es: 'Año',
    AppLang.fr: 'Année',
    AppLang.de: 'Jahr',
    AppLang.it: 'Anno',
    AppLang.pt: 'Ano',
  },
  'period_all_time': {
    AppLang.en: 'All Time',
    AppLang.es: 'Todo',
    AppLang.fr: 'Tout',
    AppLang.de: 'Gesamt',
    AppLang.it: 'Tutto',
    AppLang.pt: 'Tudo',
  },
  'export_to_csv': {
    AppLang.en: 'Export to CSV',
    AppLang.es: 'Exportar a CSV',
    AppLang.fr: 'Exporter en CSV',
    AppLang.de: 'Als CSV exportieren',
    AppLang.it: 'Esporta in CSV',
    AppLang.pt: 'Exportar para CSV',
  },
  'export_period_note': {
    AppLang.en: 'Data will be exported for the selected period',
    AppLang.es: 'Los datos se exportarán para el periodo seleccionado',
    AppLang.fr: 'Les données seront exportées pour la période sélectionnée',
    AppLang.de: 'Die Daten werden für den ausgewählten Zeitraum exportiert',
    AppLang.it: 'I dati saranno esportati per il periodo selezionato',
    AppLang.pt: 'Os dados serão exportados para o período selecionado',
  },
  // ── Insights generados ──
  'insight_balanced': {
    AppLang.en: 'Pressure distribution is well balanced between both feet.',
    AppLang.es: 'La distribución de presión está bien equilibrada entre ambos pies.',
    AppLang.fr: 'La répartition de la pression est bien équilibrée entre les deux pieds.',
    AppLang.de: 'Die Druckverteilung ist zwischen beiden Füßen gut ausgeglichen.',
    AppLang.it: 'La distribuzione della pressione è ben bilanciata tra i due piedi.',
    AppLang.pt: 'A distribuição de pressão está bem equilibrada entre os dois pés.',
  },
  'insight_favors_side': {
    AppLang.en: 'Pressure distribution favors the {side} foot ({right}% right / {left}% left).',
    AppLang.es: 'La distribución de presión favorece al pie {side} ({right}% derecha / {left}% izquierda).',
    AppLang.fr: 'La répartition de la pression favorise le pied {side} ({right}% droit / {left}% gauche).',
    AppLang.de: 'Die Druckverteilung begünstigt den {side} Fuß ({right}% rechts / {left}% links).',
    AppLang.it: 'La distribuzione della pressione favorisce il piede {side} ({right}% destro / {left}% sinistro).',
    AppLang.pt: 'A distribuição de pressão favorece o pé {side} ({right}% direito / {left}% esquerdo).',
  },
  'insight_fatigue_rising': {
    AppLang.en: 'Impact increased noticeably towards the end of the session, a sign of fatigue.',
    AppLang.es: 'El impacto aumentó notablemente hacia el final de la sesión, un signo de fatiga.',
    AppLang.fr: "L'impact a augmenté nettement vers la fin de la session, un signe de fatigue.",
    AppLang.de: 'Der Impact nahm gegen Ende der Sitzung deutlich zu, ein Anzeichen für Ermüdung.',
    AppLang.it: "L'impatto è aumentato notevolmente verso la fine della sessione, un segno di affaticamento.",
    AppLang.pt: 'O impacto aumentou visivelmente perto do fim da sessão, um sinal de fadiga.',
  },
  'insight_fatigue_stable': {
    AppLang.en: 'Impact stayed consistent throughout the session, with no clear sign of fatigue.',
    AppLang.es: 'El impacto se mantuvo constante durante toda la sesión, sin signos claros de fatiga.',
    AppLang.fr: "L'impact est resté constant tout au long de la session, sans signe clair de fatigue.",
    AppLang.de: 'Der Impact blieb während der gesamten Sitzung konstant, ohne klares Anzeichen für Ermüdung.',
    AppLang.it: "L'impatto è rimasto costante per tutta la sessione, senza segni evidenti di affaticamento.",
    AppLang.pt: 'O impacto manteve-se constante ao longo da sessão, sem sinais claros de fadiga.',
  },
  'insight_stride_longer': {
    AppLang.en: 'Stride length was longer than expected for your height.',
    AppLang.es: 'La longitud de zancada fue mayor de lo esperado para tu altura.',
    AppLang.fr: "La longueur de foulée était plus grande que prévu pour votre taille.",
    AppLang.de: 'Die Schrittlänge war länger als für deine Größe erwartet.',
    AppLang.it: 'La lunghezza del passo è stata maggiore del previsto per la tua altezza.',
    AppLang.pt: 'O comprimento da passada foi maior do que o esperado para a sua altura.',
  },
  'insight_stride_shorter': {
    AppLang.en: 'Stride length was shorter than expected for your height.',
    AppLang.es: 'La longitud de zancada fue menor de lo esperado para tu altura.',
    AppLang.fr: "La longueur de foulée était plus courte que prévu pour votre taille.",
    AppLang.de: 'Die Schrittlänge war kürzer als für deine Größe erwartet.',
    AppLang.it: 'La lunghezza del passo è stata minore del previsto per la tua altezza.',
    AppLang.pt: 'O comprimento da passada foi menor do que o esperado para a sua altura.',
  },
  'insight_not_enough_data': {
    AppLang.en: 'Not enough data yet to generate insights for this session.',
    AppLang.es: 'Todavía no hay datos suficientes para generar información sobre esta sesión.',
    AppLang.fr: "Pas encore assez de données pour générer des informations sur cette session.",
    AppLang.de: 'Noch nicht genug Daten, um Erkenntnisse für diese Sitzung zu erstellen.',
    AppLang.it: 'Non ci sono ancora dati sufficienti per generare informazioni su questa sessione.',
    AppLang.pt: 'Ainda não há dados suficientes para gerar informações sobre esta sessão.',
  },
  // ── Detalle de actividad ──
  'delete_activity_title': {
    AppLang.en: 'Delete activity?',
    AppLang.es: '¿Eliminar actividad?',
    AppLang.fr: "Supprimer l'activité ?",
    AppLang.de: 'Aktivität löschen?',
    AppLang.it: "Eliminare l'attività?",
    AppLang.pt: 'Eliminar atividade?',
  },
  'action_cannot_be_undone': {
    AppLang.en: "This action can't be undone.",
    AppLang.es: 'Esta acción no se puede deshacer.',
    AppLang.fr: 'Cette action est irréversible.',
    AppLang.de: 'Diese Aktion kann nicht rückgängig gemacht werden.',
    AppLang.it: "Questa azione non può essere annullata.",
    AppLang.pt: 'Esta ação não pode ser desfeita.',
  },
  'delete_button': {
    AppLang.en: 'Delete',
    AppLang.es: 'Eliminar',
    AppLang.fr: 'Supprimer',
    AppLang.de: 'Löschen',
    AppLang.it: 'Elimina',
    AppLang.pt: 'Eliminar',
  },
  'activity_details': {
    AppLang.en: 'Activity Details',
    AppLang.es: 'Detalles de la actividad',
    AppLang.fr: "Détails de l'activité",
    AppLang.de: 'Aktivitätsdetails',
    AppLang.it: 'Dettagli attività',
    AppLang.pt: 'Detalhes da atividade',
  },
  'changes_saved': {
    AppLang.en: 'Changes saved',
    AppLang.es: 'Cambios guardados',
    AppLang.fr: 'Modifications enregistrées',
    AppLang.de: 'Änderungen gespeichert',
    AppLang.it: 'Modifiche salvate',
    AppLang.pt: 'Alterações guardadas',
  },
  'notes_label': {
    AppLang.en: 'Notes',
    AppLang.es: 'Notas',
    AppLang.fr: 'Notes',
    AppLang.de: 'Notizen',
    AppLang.it: 'Note',
    AppLang.pt: 'Notas',
  },
  'no_notes': {
    AppLang.en: 'No notes',
    AppLang.es: 'Sin notas',
    AppLang.fr: 'Aucune note',
    AppLang.de: 'Keine Notizen',
    AppLang.it: 'Nessuna nota',
    AppLang.pt: 'Sem notas',
  },
  'performance_score': {
    AppLang.en: 'Performance Score',
    AppLang.es: 'Puntuación de rendimiento',
    AppLang.fr: 'Score de performance',
    AppLang.de: 'Leistungswert',
    AppLang.it: 'Punteggio prestazione',
    AppLang.pt: 'Pontuação de desempenho',
  },
  'performance_score_info': {
    AppLang.en: 'Combines how symmetric (Balance), how consistent (Fatigue Index) and how close to your expected stride the session was. 100 = ideal on all three.',
    AppLang.es: 'Combina lo simétrica (Equilibrio), lo constante (Índice de fatiga) y lo cercana a tu zancada esperada que fue la sesión. 100 = ideal en las tres.',
    AppLang.fr: "Combine la symétrie (Équilibre), la régularité (Indice de fatigue) et la proximité avec votre foulée attendue. 100 = idéal sur les trois.",
    AppLang.de: 'Kombiniert, wie symmetrisch (Balance), wie gleichmäßig (Ermüdungsindex) und wie nah an deiner erwarteten Schrittlänge die Sitzung war. 100 = ideal bei allen dreien.',
    AppLang.it: "Combina quanto è stata simmetrica (Equilibrio), costante (Indice di affaticamento) e vicina al passo atteso la sessione. 100 = ideale su tutti e tre.",
    AppLang.pt: 'Combina o quão simétrica (Equilíbrio), consistente (Índice de fadiga) e próxima da sua passada esperada foi a sessão. 100 = ideal nas três.',
  },
  'score_excellent': {
    AppLang.en: 'Excellent',
    AppLang.es: 'Excelente',
    AppLang.fr: 'Excellent',
    AppLang.de: 'Ausgezeichnet',
    AppLang.it: 'Eccellente',
    AppLang.pt: 'Excelente',
  },
  'score_good': {
    AppLang.en: 'Good',
    AppLang.es: 'Bueno',
    AppLang.fr: 'Bon',
    AppLang.de: 'Gut',
    AppLang.it: 'Buono',
    AppLang.pt: 'Bom',
  },
  'score_fair': {
    AppLang.en: 'Fair',
    AppLang.es: 'Aceptable',
    AppLang.fr: 'Correct',
    AppLang.de: 'Befriedigend',
    AppLang.it: 'Sufficiente',
    AppLang.pt: 'Razoável',
  },
  'score_needs_improvement': {
    AppLang.en: 'Needs improvement',
    AppLang.es: 'Necesita mejorar',
    AppLang.fr: 'À améliorer',
    AppLang.de: 'Verbesserungswürdig',
    AppLang.it: 'Da migliorare',
    AppLang.pt: 'Precisa de melhorar',
  },
  'stride_vs_expected': {
    AppLang.en: 'Stride vs. expected for height',
    AppLang.es: 'Zancada vs. esperada para tu altura',
    AppLang.fr: 'Foulée vs. attendue pour la taille',
    AppLang.de: 'Schrittlänge vs. erwartet für die Größe',
    AppLang.it: 'Passo vs. atteso per altezza',
    AppLang.pt: 'Passada vs. esperada para a altura',
  },
  'stride_info': {
    AppLang.en: 'Your real stride length vs. the typical one for your height and activity type. 100% = exactly as expected.',
    AppLang.es: 'Tu longitud de zancada real frente a la típica para tu altura y tipo de actividad. 100% = justo lo esperado.',
    AppLang.fr: "Votre longueur de foulée réelle par rapport à celle typique pour votre taille et type d'activité. 100% = exactement comme attendu.",
    AppLang.de: 'Deine reale Schrittlänge im Vergleich zur typischen für deine Größe und Aktivitätsart. 100% = genau wie erwartet.',
    AppLang.it: 'La tua lunghezza del passo reale rispetto a quella tipica per la tua altezza e tipo di attività. 100% = esattamente come previsto.',
    AppLang.pt: 'O comprimento real da sua passada em comparação com o típico para a sua altura e tipo de atividade. 100% = exatamente o esperado.',
  },
  'route_label': {
    AppLang.en: 'Route',
    AppLang.es: 'Recorrido',
    AppLang.fr: 'Parcours',
    AppLang.de: 'Strecke',
    AppLang.it: 'Percorso',
    AppLang.pt: 'Percurso',
  },
  'pressure_analysis_summary': {
    AppLang.en: 'Plantar Pressure Analysis Summary',
    AppLang.es: 'Resumen del análisis de presión plantar',
    AppLang.fr: 'Résumé de l\'analyse de la pression plantaire',
    AppLang.de: 'Zusammenfassung der Fußsohlendruckanalyse',
    AppLang.it: 'Riepilogo analisi pressione plantare',
    AppLang.pt: 'Resumo da análise de pressão plantar',
  },
  'pressure_distribution_breakdown': {
    AppLang.en: 'Pressure Distribution Breakdown',
    AppLang.es: 'Desglose de la distribución de presión',
    AppLang.fr: 'Répartition détaillée de la pression',
    AppLang.de: 'Aufschlüsselung der Druckverteilung',
    AppLang.it: 'Ripartizione della distribuzione della pressione',
    AppLang.pt: 'Detalhe da distribuição de pressão',
  },
  'heel_metatarsal_info': {
    AppLang.en: 'Estimated split of each foot\'s pressure between heel and metatarsal, based on the gait phase at each instant (not measured directly with two separate sensors). It\'s an average over the whole session, not a peak — a low number is normal, since it also counts the time spent mid-stance or with the foot lifted.',
    AppLang.es: 'Reparto estimado de la presión de cada pie entre talón y metatarso, según la fase de marcha en cada instante (no se mide directamente con dos sensores separados). Es una media de toda la sesión, no un pico: un número bajo es normal, ya que también cuenta el tiempo en apoyo medio o con el pie en el aire.',
    AppLang.fr: "Répartition estimée de la pression de chaque pied entre talon et métatarse, selon la phase de marche à chaque instant (non mesurée directement avec deux capteurs séparés). C'est une moyenne sur toute la session, pas un pic : un chiffre bas est normal, car il inclut aussi le temps en appui moyen ou pied en l'air.",
    AppLang.de: 'Geschätzte Aufteilung des Drucks jedes Fußes zwischen Ferse und Mittelfuß, je nach Gangphase zu jedem Zeitpunkt (nicht direkt mit zwei getrennten Sensoren gemessen). Es ist ein Durchschnitt über die gesamte Sitzung, kein Spitzenwert – ein niedriger Wert ist normal, da auch die Zeit in der Mittelstandsphase oder mit angehobenem Fuß mitzählt.',
    AppLang.it: "Ripartizione stimata della pressione di ogni piede tra tallone e metatarso, in base alla fase del passo in ogni istante (non misurata direttamente con due sensori separati). È una media sull'intera sessione, non un picco: un numero basso è normale, poiché conta anche il tempo in appoggio medio o con il piede sollevato.",
    AppLang.pt: 'Divisão estimada da pressão de cada pé entre calcanhar e metatarso, com base na fase de marcha em cada instante (não medida diretamente com dois sensores separados). É uma média de toda a sessão, não um pico: um número baixo é normal, já que também conta o tempo em apoio médio ou com o pé no ar.',
  },
  'heel_label': {
    AppLang.en: 'Heel',
    AppLang.es: 'Talón',
    AppLang.fr: 'Talon',
    AppLang.de: 'Ferse',
    AppLang.it: 'Tallone',
    AppLang.pt: 'Calcanhar',
  },
  'metatarsal_label': {
    AppLang.en: 'Metatarsal',
    AppLang.es: 'Metatarso',
    AppLang.fr: 'Métatarse',
    AppLang.de: 'Mittelfuß',
    AppLang.it: 'Metatarso',
    AppLang.pt: 'Metatarso',
  },
  'biomechanical_metrics': {
    AppLang.en: 'Biomechanical Metrics',
    AppLang.es: 'Métricas biomecánicas',
    AppLang.fr: 'Métriques biomécaniques',
    AppLang.de: 'Biomechanische Metriken',
    AppLang.it: 'Metriche biomeccaniche',
    AppLang.pt: 'Métricas biomecânicas',
  },
  'both_label': {
    AppLang.en: 'Both',
    AppLang.es: 'Ambos',
    AppLang.fr: 'Les deux',
    AppLang.de: 'Beide',
    AppLang.it: 'Entrambi',
    AppLang.pt: 'Ambos',
  },
  'right_dominant': {
    AppLang.en: 'Right dominant',
    AppLang.es: 'Predomina derecha',
    AppLang.fr: 'Dominance droite',
    AppLang.de: 'Rechts dominant',
    AppLang.it: 'Prevale destra',
    AppLang.pt: 'Predomínio direito',
  },
  'left_dominant': {
    AppLang.en: 'Left dominant',
    AppLang.es: 'Predomina izquierda',
    AppLang.fr: 'Dominance gauche',
    AppLang.de: 'Links dominant',
    AppLang.it: 'Prevale sinistra',
    AppLang.pt: 'Predomínio esquerdo',
  },
  'symmetric_label': {
    AppLang.en: 'Symmetric',
    AppLang.es: 'Simétrico',
    AppLang.fr: 'Symétrique',
    AppLang.de: 'Symmetrisch',
    AppLang.it: 'Simmetrico',
    AppLang.pt: 'Simétrico',
  },
  'balance_info': {
    AppLang.en: 'Both: how far from a 50/50 split the session was (0% = perfectly balanced, 100% = all weight on one foot). Left/Right: the share of pressure carried by that foot.',
    AppLang.es: 'Ambos: cuánto se alejó la sesión de un reparto 50/50 (0% = perfectamente equilibrado, 100% = todo el peso en un pie). Izquierda/Derecha: la parte de presión que soportó ese pie.',
    AppLang.fr: "Les deux : à quelle distance d'une répartition 50/50 était la session (0% = parfaitement équilibré, 100% = tout le poids sur un pied). Gauche/Droite : la part de pression portée par ce pied.",
    AppLang.de: 'Beide: wie weit die Sitzung von einer 50/50-Aufteilung entfernt war (0% = perfekt ausgeglichen, 100% = gesamtes Gewicht auf einem Fuß). Links/Rechts: der Druckanteil dieses Fußes.',
    AppLang.it: "Entrambi: quanto la sessione si è discostata da una ripartizione 50/50 (0% = perfettamente bilanciata, 100% = tutto il peso su un piede). Sinistra/Destra: la quota di pressione sostenuta da quel piede.",
    AppLang.pt: 'Ambos: o quanto a sessão se afastou de uma divisão 50/50 (0% = perfeitamente equilibrado, 100% = todo o peso num pé). Esquerdo/Direito: a parte da pressão suportada por esse pé.',
  },
  'impact_info': {
    AppLang.en: 'Average intensity of each heel contact. A higher value means harder footstrikes, not just walking faster.',
    AppLang.es: 'Intensidad media de cada contacto de talón. Un valor más alto significa pisadas más fuertes, no solo caminar más rápido.',
    AppLang.fr: "Intensité moyenne de chaque contact du talon. Une valeur plus élevée signifie des foulées plus fortes, pas seulement une marche plus rapide.",
    AppLang.de: 'Durchschnittliche Intensität jedes Fersenkontakts. Ein höherer Wert bedeutet härtere Schritte, nicht nur schnelleres Gehen.',
    AppLang.it: "Intensità media di ogni contatto del tallone. Un valore più alto significa appoggi più forti, non solo camminare più veloce.",
    AppLang.pt: 'Intensidade média de cada contacto do calcanhar. Um valor mais alto significa passadas mais fortes, não apenas caminhar mais depressa.',
  },
  'fatigue_index': {
    AppLang.en: 'Fatigue Index',
    AppLang.es: 'Índice de fatiga',
    AppLang.fr: 'Indice de fatigue',
    AppLang.de: 'Ermüdungsindex',
    AppLang.it: 'Indice di affaticamento',
    AppLang.pt: 'Índice de fadiga',
  },
  'fatigue_index_info': {
    AppLang.en: 'How much heel impact rose in the last third of the session compared to the first. Rising impact over time is a common sign of fatigue.',
    AppLang.es: 'Cuánto aumentó el impacto de talón en el último tercio de la sesión respecto al primero. Un impacto creciente con el tiempo es un signo común de fatiga.',
    AppLang.fr: "De combien l'impact du talon a augmenté dans le dernier tiers de la session par rapport au premier. Une augmentation de l'impact dans le temps est un signe courant de fatigue.",
    AppLang.de: 'Wie stark der Fersen-Impact im letzten Drittel der Sitzung im Vergleich zum ersten anstieg. Ein zunehmender Impact über die Zeit ist ein häufiges Anzeichen für Ermüdung.',
    AppLang.it: "Quanto è aumentato l'impatto del tallone nell'ultimo terzo della sessione rispetto al primo. Un impatto crescente nel tempo è un segno comune di affaticamento.",
    AppLang.pt: 'Quanto o impacto do calcanhar aumentou no último terço da sessão em relação ao primeiro. Um impacto crescente ao longo do tempo é um sinal comum de fadiga.',
  },
  'fatigue_rising': {
    AppLang.en: 'Rising',
    AppLang.es: 'Subiendo',
    AppLang.fr: 'En hausse',
    AppLang.de: 'Steigend',
    AppLang.it: 'In aumento',
    AppLang.pt: 'A subir',
  },
  'fatigue_stable': {
    AppLang.en: 'Stable',
    AppLang.es: 'Estable',
    AppLang.fr: 'Stable',
    AppLang.de: 'Stabil',
    AppLang.it: 'Stabile',
    AppLang.pt: 'Estável',
  },
  'start_label': {
    AppLang.en: 'Start',
    AppLang.es: 'Inicio',
    AppLang.fr: 'Début',
    AppLang.de: 'Start',
    AppLang.it: 'Inizio',
    AppLang.pt: 'Início',
  },
  'mid_label': {
    AppLang.en: 'Mid',
    AppLang.es: 'Medio',
    AppLang.fr: 'Milieu',
    AppLang.de: 'Mitte',
    AppLang.it: 'Metà',
    AppLang.pt: 'Meio',
  },
  'end_label': {
    AppLang.en: 'End',
    AppLang.es: 'Fin',
    AppLang.fr: 'Fin',
    AppLang.de: 'Ende',
    AppLang.it: 'Fine',
    AppLang.pt: 'Fim',
  },
  'strike_index': {
    AppLang.en: 'Strike Index',
    AppLang.es: 'Índice de pisada',
    AppLang.fr: 'Indice de frappe',
    AppLang.de: 'Auftrittsindex',
    AppLang.it: 'Indice di appoggio',
    AppLang.pt: 'Índice de contacto',
  },
  'strike_index_info': {
    AppLang.en: 'Which part of the foot lands first at initial contact: 0% = heel strike, 50% = midfoot, 100% = forefoot strike.',
    AppLang.es: 'Qué parte del pie toca el suelo primero en el contacto inicial: 0% = talón, 50% = mediopié, 100% = antepié.',
    AppLang.fr: "Quelle partie du pied touche le sol en premier au contact initial : 0% = talon, 50% = médio-pied, 100% = avant-pied.",
    AppLang.de: 'Welcher Teil des Fußes bei Erstkontakt zuerst aufsetzt: 0% = Fersenauftritt, 50% = Mittelfuß, 100% = Vorfußauftritt.',
    AppLang.it: "Quale parte del piede tocca il suolo per prima al contatto iniziale: 0% = tallone, 50% = mesopiede, 100% = avampiede.",
    AppLang.pt: 'Que parte do pé toca o solo primeiro no contacto inicial: 0% = calcanhar, 50% = mediopé, 100% = antepé.',
  },
  'strike_heel': {
    AppLang.en: 'Heel strike',
    AppLang.es: 'Apoyo de talón',
    AppLang.fr: 'Attaque talon',
    AppLang.de: 'Fersenauftritt',
    AppLang.it: 'Appoggio di tallone',
    AppLang.pt: 'Contacto de calcanhar',
  },
  'strike_midfoot': {
    AppLang.en: 'Midfoot',
    AppLang.es: 'Mediopié',
    AppLang.fr: 'Médio-pied',
    AppLang.de: 'Mittelfuß',
    AppLang.it: 'Mesopiede',
    AppLang.pt: 'Mediopé',
  },
  'strike_forefoot': {
    AppLang.en: 'Forefoot',
    AppLang.es: 'Antepié',
    AppLang.fr: 'Avant-pied',
    AppLang.de: 'Vorfuß',
    AppLang.it: 'Avampiede',
    AppLang.pt: 'Antepé',
  },
  'insights_title': {
    AppLang.en: 'Insights',
    AppLang.es: 'Información',
    AppLang.fr: 'Analyses',
    AppLang.de: 'Erkenntnisse',
    AppLang.it: 'Approfondimenti',
    AppLang.pt: 'Informações',
  },
  'cadence_info': {
    AppLang.en: 'Steps per minute, averaged over the whole session (both feet combined).',
    AppLang.es: 'Pasos por minuto, promediados durante toda la sesión (ambos pies combinados).',
    AppLang.fr: "Pas par minute, moyennés sur toute la session (les deux pieds combinés).",
    AppLang.de: 'Schritte pro Minute, gemittelt über die gesamte Sitzung (beide Füße kombiniert).',
    AppLang.it: "Passi al minuto, mediati sull'intera sessione (entrambi i piedi combinati).",
    AppLang.pt: 'Passos por minuto, com média ao longo de toda a sessão (ambos os pés combinados).',
  },
  'export_as_csv': {
    AppLang.en: 'Export as CSV',
    AppLang.es: 'Exportar como CSV',
    AppLang.fr: 'Exporter en CSV',
    AppLang.de: 'Als CSV exportieren',
    AppLang.it: 'Esporta come CSV',
    AppLang.pt: 'Exportar como CSV',
  },
  // ── Meses ──
  'month_1': {AppLang.en: 'January', AppLang.es: 'enero', AppLang.fr: 'janvier', AppLang.de: 'Januar', AppLang.it: 'gennaio', AppLang.pt: 'janeiro'},
  'month_2': {AppLang.en: 'February', AppLang.es: 'febrero', AppLang.fr: 'février', AppLang.de: 'Februar', AppLang.it: 'febbraio', AppLang.pt: 'fevereiro'},
  'month_3': {AppLang.en: 'March', AppLang.es: 'marzo', AppLang.fr: 'mars', AppLang.de: 'März', AppLang.it: 'marzo', AppLang.pt: 'março'},
  'month_4': {AppLang.en: 'April', AppLang.es: 'abril', AppLang.fr: 'avril', AppLang.de: 'April', AppLang.it: 'aprile', AppLang.pt: 'abril'},
  'month_5': {AppLang.en: 'May', AppLang.es: 'mayo', AppLang.fr: 'mai', AppLang.de: 'Mai', AppLang.it: 'maggio', AppLang.pt: 'maio'},
  'month_6': {AppLang.en: 'June', AppLang.es: 'junio', AppLang.fr: 'juin', AppLang.de: 'Juni', AppLang.it: 'giugno', AppLang.pt: 'junho'},
  'month_7': {AppLang.en: 'July', AppLang.es: 'julio', AppLang.fr: 'juillet', AppLang.de: 'Juli', AppLang.it: 'luglio', AppLang.pt: 'julho'},
  'month_8': {AppLang.en: 'August', AppLang.es: 'agosto', AppLang.fr: 'août', AppLang.de: 'August', AppLang.it: 'agosto', AppLang.pt: 'agosto'},
  'month_9': {AppLang.en: 'September', AppLang.es: 'septiembre', AppLang.fr: 'septembre', AppLang.de: 'September', AppLang.it: 'settembre', AppLang.pt: 'setembro'},
  'month_10': {AppLang.en: 'October', AppLang.es: 'octubre', AppLang.fr: 'octobre', AppLang.de: 'Oktober', AppLang.it: 'ottobre', AppLang.pt: 'outubro'},
  'month_11': {AppLang.en: 'November', AppLang.es: 'noviembre', AppLang.fr: 'novembre', AppLang.de: 'November', AppLang.it: 'novembre', AppLang.pt: 'novembro'},
  'month_12': {AppLang.en: 'December', AppLang.es: 'diciembre', AppLang.fr: 'décembre', AppLang.de: 'Dezember', AppLang.it: 'dicembre', AppLang.pt: 'dezembro'},
  'member_since': {
    AppLang.en: 'Member since {month} {year}',
    AppLang.es: 'Miembro desde {month} de {year}',
    AppLang.fr: 'Membre depuis {month} {year}',
    AppLang.de: 'Mitglied seit {month} {year}',
    AppLang.it: 'Membro da {month} {year}',
    AppLang.pt: 'Membro desde {month} de {year}',
  },
  // ── Condiciones del pie ──
  'condition_none': {
    AppLang.en: 'No conditions',
    AppLang.es: 'Sin condiciones',
    AppLang.fr: 'Aucune condition',
    AppLang.de: 'Keine Beschwerden',
    AppLang.it: 'Nessuna condizione',
    AppLang.pt: 'Sem condições',
  },
  'condition_plantar_fasciitis': {
    AppLang.en: 'Plantar Fasciitis',
    AppLang.es: 'Fascitis plantar',
    AppLang.fr: 'Fasciite plantaire',
    AppLang.de: 'Plantarfasziitis',
    AppLang.it: 'Fascite plantare',
    AppLang.pt: 'Fascite plantar',
  },
  'condition_bunions': {
    AppLang.en: 'Bunions',
    AppLang.es: 'Juanetes',
    AppLang.fr: 'Oignons',
    AppLang.de: 'Ballenzehen',
    AppLang.it: 'Alluce valgo',
    AppLang.pt: 'Joanetes',
  },
  'condition_arthritis': {
    AppLang.en: 'Arthritis',
    AppLang.es: 'Artritis',
    AppLang.fr: 'Arthrite',
    AppLang.de: 'Arthritis',
    AppLang.it: 'Artrite',
    AppLang.pt: 'Artrite',
  },
  'condition_other': {
    AppLang.en: 'Other',
    AppLang.es: 'Otra',
    AppLang.fr: 'Autre',
    AppLang.de: 'Andere',
    AppLang.it: 'Altro',
    AppLang.pt: 'Outra',
  },
  // ── Ajustes / Perfil ──
  'delete_account_title': {
    AppLang.en: 'Delete account?',
    AppLang.es: '¿Eliminar cuenta?',
    AppLang.fr: 'Supprimer le compte ?',
    AppLang.de: 'Konto löschen?',
    AppLang.it: "Eliminare l'account?",
    AppLang.pt: 'Eliminar conta?',
  },
  'delete_account_msg': {
    AppLang.en: "This action can't be undone. Your profile, calibration and session history will be permanently deleted.",
    AppLang.es: 'Esta acción no se puede deshacer. Tu perfil, calibración e historial de sesiones se eliminarán de forma permanente.',
    AppLang.fr: "Cette action est irréversible. Votre profil, votre étalonnage et votre historique de sessions seront supprimés définitivement.",
    AppLang.de: 'Diese Aktion kann nicht rückgängig gemacht werden. Dein Profil, deine Kalibrierung und dein Sitzungsverlauf werden dauerhaft gelöscht.',
    AppLang.it: "Questa azione non può essere annullata. Il tuo profilo, la calibrazione e la cronologia delle sessioni verranno eliminati permanentemente.",
    AppLang.pt: 'Esta ação não pode ser desfeita. O seu perfil, calibração e histórico de sessões serão eliminados permanentemente.',
  },
  'err_reauth_required': {
    AppLang.en: 'Please sign in again before deleting your account.',
    AppLang.es: 'Vuelve a iniciar sesión antes de eliminar tu cuenta.',
    AppLang.fr: 'Veuillez vous reconnecter avant de supprimer votre compte.',
    AppLang.de: 'Bitte melde dich erneut an, bevor du dein Konto löschst.',
    AppLang.it: "Accedi di nuovo prima di eliminare il tuo account.",
    AppLang.pt: 'Inicie sessão novamente antes de eliminar a sua conta.',
  },
  'err_deleting_account': {
    AppLang.en: 'Error deleting account',
    AppLang.es: 'Error al eliminar la cuenta',
    AppLang.fr: 'Erreur lors de la suppression du compte',
    AppLang.de: 'Fehler beim Löschen des Kontos',
    AppLang.it: "Errore durante l'eliminazione dell'account",
    AppLang.pt: 'Erro ao eliminar a conta',
  },
  'profile_title': {
    AppLang.en: 'Profile',
    AppLang.es: 'Perfil',
    AppLang.fr: 'Profil',
    AppLang.de: 'Profil',
    AppLang.it: 'Profilo',
    AppLang.pt: 'Perfil',
  },
  'personal_data': {
    AppLang.en: 'Personal Data',
    AppLang.es: 'Datos personales',
    AppLang.fr: 'Données personnelles',
    AppLang.de: 'Persönliche Daten',
    AppLang.it: 'Dati personali',
    AppLang.pt: 'Dados pessoais',
  },
  'name_label': {
    AppLang.en: 'Name',
    AppLang.es: 'Nombre',
    AppLang.fr: 'Prénom',
    AppLang.de: 'Vorname',
    AppLang.it: 'Nome',
    AppLang.pt: 'Nome',
  },
  'date_of_birth_break': {
    AppLang.en: 'Date of\nBirth',
    AppLang.es: 'Fecha de\nnacimiento',
    AppLang.fr: 'Date de\nnaissance',
    AppLang.de: 'Geburts-\ndatum',
    AppLang.it: 'Data di\nnascita',
    AppLang.pt: 'Data de\nnascimento',
  },
  'date_of_birth': {
    AppLang.en: 'Date of Birth',
    AppLang.es: 'Fecha de nacimiento',
    AppLang.fr: 'Date de naissance',
    AppLang.de: 'Geburtsdatum',
    AppLang.it: 'Data di nascita',
    AppLang.pt: 'Data de nascimento',
  },
  'physical_metrics': {
    AppLang.en: 'Physical Metrics',
    AppLang.es: 'Medidas físicas',
    AppLang.fr: 'Mesures physiques',
    AppLang.de: 'Körperliche Daten',
    AppLang.it: 'Misure fisiche',
    AppLang.pt: 'Medidas físicas',
  },
  'shoe_size_label': {
    AppLang.en: 'Shoe Size',
    AppLang.es: 'Talla de zapato',
    AppLang.fr: 'Pointure',
    AppLang.de: 'Schuhgröße',
    AppLang.it: 'Numero di scarpe',
    AppLang.pt: 'Tamanho de calçado',
  },
  'biomechanics_title': {
    AppLang.en: 'Biomechanics',
    AppLang.es: 'Biomecánica',
    AppLang.fr: 'Biomécanique',
    AppLang.de: 'Biomechanik',
    AppLang.it: 'Biomeccanica',
    AppLang.pt: 'Biomecânica',
  },
  'foot_arch_label': {
    AppLang.en: 'Foot Arch',
    AppLang.es: 'Arco plantar',
    AppLang.fr: 'Voûte plantaire',
    AppLang.de: 'Fußgewölbe',
    AppLang.it: 'Arco plantare',
    AppLang.pt: 'Arco plantar',
  },
  'condition_label': {
    AppLang.en: 'Condition',
    AppLang.es: 'Condición',
    AppLang.fr: 'Condition',
    AppLang.de: 'Beschwerde',
    AppLang.it: 'Condizione',
    AppLang.pt: 'Condição',
  },
  'metrics_guide_title': {
    AppLang.en: 'Metrics Guide',
    AppLang.es: 'Guía de métricas',
    AppLang.fr: 'Guide des métriques',
    AppLang.de: 'Metriken-Leitfaden',
    AppLang.it: 'Guida alle metriche',
    AppLang.pt: 'Guia de métricas',
  },
  'sign_out': {
    AppLang.en: 'Sign Out',
    AppLang.es: 'Cerrar sesión',
    AppLang.fr: 'Se déconnecter',
    AppLang.de: 'Abmelden',
    AppLang.it: 'Esci',
    AppLang.pt: 'Terminar sessão',
  },
  'at_word': {
    AppLang.en: 'at',
    AppLang.es: 'a las',
    AppLang.fr: 'à',
    AppLang.de: 'um',
    AppLang.it: 'alle',
    AppLang.pt: 'às',
  },
  'delete_account': {
    AppLang.en: 'Delete Account',
    AppLang.es: 'Eliminar cuenta',
    AppLang.fr: 'Supprimer le compte',
    AppLang.de: 'Konto löschen',
    AppLang.it: 'Elimina account',
    AppLang.pt: 'Eliminar conta',
  },
  // ── Guía de métricas ──
  'metrics_guide_subtitle': {
    AppLang.en: 'What each number means, where it comes from, and how to read it.',
    AppLang.es: 'Qué significa cada número, de dónde sale y cómo interpretarlo.',
    AppLang.fr: "Ce que signifie chaque chiffre, d'où il vient et comment le lire.",
    AppLang.de: 'Was jede Zahl bedeutet, woher sie kommt und wie man sie liest.',
    AppLang.it: 'Cosa significa ogni numero, da dove viene e come leggerlo.',
    AppLang.pt: 'O que significa cada número, de onde vem e como o interpretar.',
  },
  'weekday_1': {
    AppLang.en: 'Mon',
    AppLang.es: 'Lun',
    AppLang.fr: 'Lun',
    AppLang.de: 'Mo',
    AppLang.it: 'Lun',
    AppLang.pt: 'Seg',
  },
  'weekday_2': {
    AppLang.en: 'Tue',
    AppLang.es: 'Mar',
    AppLang.fr: 'Mar',
    AppLang.de: 'Di',
    AppLang.it: 'Mar',
    AppLang.pt: 'Ter',
  },
  'weekday_3': {
    AppLang.en: 'Wed',
    AppLang.es: 'Mié',
    AppLang.fr: 'Mer',
    AppLang.de: 'Mi',
    AppLang.it: 'Mer',
    AppLang.pt: 'Qua',
  },
  'weekday_4': {
    AppLang.en: 'Thu',
    AppLang.es: 'Jue',
    AppLang.fr: 'Jeu',
    AppLang.de: 'Do',
    AppLang.it: 'Gio',
    AppLang.pt: 'Qui',
  },
  'weekday_5': {
    AppLang.en: 'Fri',
    AppLang.es: 'Vie',
    AppLang.fr: 'Ven',
    AppLang.de: 'Fr',
    AppLang.it: 'Ven',
    AppLang.pt: 'Sex',
  },
  'weekday_6': {
    AppLang.en: 'Sat',
    AppLang.es: 'Sáb',
    AppLang.fr: 'Sam',
    AppLang.de: 'Sa',
    AppLang.it: 'Sab',
    AppLang.pt: 'Sáb',
  },
  'weekday_7': {
    AppLang.en: 'Sun',
    AppLang.es: 'Dom',
    AppLang.fr: 'Dim',
    AppLang.de: 'So',
    AppLang.it: 'Dom',
    AppLang.pt: 'Dom',
  },
  'week_label_short': {
    AppLang.en: 'Wk',
    AppLang.es: 'Sem',
    AppLang.fr: 'Sem',
    AppLang.de: 'Wo',
    AppLang.it: 'Sett',
    AppLang.pt: 'Sem',
  },
  'mg_section_vars': {
    AppLang.en: 'What it means',
    AppLang.es: 'Qué significa',
    AppLang.fr: 'Ce que ça veut dire',
    AppLang.de: 'Was es bedeutet',
    AppLang.it: 'Cosa significa',
    AppLang.pt: 'O que significa',
  },
  'mg_section_valores': {
    AppLang.en: 'Typical values',
    AppLang.es: 'Valores típicos',
    AppLang.fr: 'Valeurs typiques',
    AppLang.de: 'Typische Werte',
    AppLang.it: 'Valori tipici',
    AppLang.pt: 'Valores típicos',
  },
  'mg_balance_def': {
    AppLang.en: 'Pressure split between your two feet.',
    AppLang.es: 'Reparto de presión entre tus dos pies.',
    AppLang.fr: 'Répartition de la pression entre vos deux pieds.',
    AppLang.de: 'Druckverteilung zwischen deinen beiden Füßen.',
    AppLang.it: 'Ripartizione della pressione tra i tuoi due piedi.',
    AppLang.pt: 'Divisão da pressão entre os seus dois pés.',
  },
  'mg_balance_var1': {
    AppLang.en: 'ΣPresRight → total pressure, right foot.',
    AppLang.es: 'ΣPresRight → presión total, pie derecho.',
    AppLang.fr: 'ΣPresRight → pression totale, pied droit.',
    AppLang.de: 'ΣPresRight → Gesamtdruck, rechter Fuß.',
    AppLang.it: 'ΣPresRight → pressione totale, piede destro.',
    AppLang.pt: 'ΣPresRight → pressão total, pé direito.',
  },
  'mg_balance_var2': {
    AppLang.en: 'ΣPresLeft → same, left foot.',
    AppLang.es: 'ΣPresLeft → lo mismo, pie izquierdo.',
    AppLang.fr: 'ΣPresLeft → pareil, pied gauche.',
    AppLang.de: 'ΣPresLeft → dasselbe, linker Fuß.',
    AppLang.it: 'ΣPresLeft → lo stesso, piede sinistro.',
    AppLang.pt: 'ΣPresLeft → o mesmo, pé esquerdo.',
  },
  'mg_balance_val1': {
    AppLang.en: '<15% → symmetric (good)',
    AppLang.es: '<15% → simétrico (bien)',
    AppLang.fr: '<15% → symétrique (bien)',
    AppLang.de: '<15% → symmetrisch (gut)',
    AppLang.it: '<15% → simmetrico (bene)',
    AppLang.pt: '<15% → simétrico (bem)',
  },
  'mg_balance_val2': {
    AppLang.en: '15-34% → moderate',
    AppLang.es: '15-34% → moderado',
    AppLang.fr: '15-34% → modéré',
    AppLang.de: '15-34% → mäßig',
    AppLang.it: '15-34% → moderato',
    AppLang.pt: '15-34% → moderado',
  },
  'mg_balance_val3': {
    AppLang.en: '≥35% → high (pay attention)',
    AppLang.es: '≥35% → alto (atención)',
    AppLang.fr: '≥35% → élevé (attention)',
    AppLang.de: '≥35% → hoch (Achtung)',
    AppLang.it: '≥35% → alto (attenzione)',
    AppLang.pt: '≥35% → alto (atenção)',
  },
  'mg_balance_nota': {
    AppLang.en: 'This % is the imbalance, not the per-foot split: 0% (symmetric) equals 50%/50% in the Activity Details breakdown.',
    AppLang.es: 'Este % es el desequilibrio, no el reparto por pie: 0% (simétrico) equivale a 50%/50% en el desglose de Detalle de actividad.',
    AppLang.fr: "Ce % est le déséquilibre, pas la répartition par pied : 0% (symétrique) équivaut à 50%/50% dans la répartition des Détails d'activité.",
    AppLang.de: 'Dieser % ist die Abweichung, nicht die Aufteilung pro Fuß: 0% (symmetrisch) entspricht 50%/50% in der Aufschlüsselung der Aktivitätsdetails.',
    AppLang.it: 'Questa % è lo squilibrio, non la ripartizione per piede: 0% (simmetrico) equivale a 50%/50% nella ripartizione dei Dettagli attività.',
    AppLang.pt: 'Esta % é o desequilíbrio, não a divisão por pé: 0% (simétrico) equivale a 50%/50% na divisão dos Detalhes da atividade.',
  },
  'mg_balance_where': {
    AppLang.en: 'Session Summary, Activity Details, Home, CSV export.',
    AppLang.es: 'Resumen de sesión, Detalle de actividad, Inicio, exportación CSV.',
    AppLang.fr: 'Résumé de session, Détails d\'activité, Accueil, export CSV.',
    AppLang.de: 'Sitzungsübersicht, Aktivitätsdetails, Home, CSV-Export.',
    AppLang.it: 'Riepilogo sessione, Dettagli attività, Home, esportazione CSV.',
    AppLang.pt: 'Resumo da sessão, Detalhes da atividade, Início, exportação CSV.',
  },
  'mg_impact_def': {
    AppLang.en: 'Average force per footstrike, as % of your calibrated body weight (100% = your full weight resting on that foot).',
    AppLang.es: 'Fuerza media de cada pisada, en % de tu peso corporal calibrado (100% = tu peso completo apoyado en ese pie).',
    AppLang.fr: "Force moyenne de chaque pas, en % de votre poids corporel étalonné (100% = votre poids complet posé sur ce pied).",
    AppLang.de: 'Durchschnittliche Kraft pro Schritt, in % deines kalibrierten Körpergewichts (100% = dein volles Gewicht auf diesem Fuß).',
    AppLang.it: "Forza media di ogni passo, in % del tuo peso corporeo calibrato (100% = il tuo peso completo appoggiato su quel piede).",
    AppLang.pt: 'Força média de cada passo, em % do seu peso corporal calibrado (100% = o seu peso total apoiado nesse pé).',
  },
  'mg_impact_var1': {
    AppLang.en: 'step peak → highest pressure (%) in one contact, already relative to your calibration.',
    AppLang.es: 'step peak → presión máxima (%) en un contacto, ya relativa a tu calibración.',
    AppLang.fr: 'step peak → pression max (%) sur un contact, déjà relative à votre étalonnage.',
    AppLang.de: 'step peak → höchster Druck (%) bei einem Kontakt, bereits relativ zu deiner Kalibrierung.',
    AppLang.it: 'step peak → pressione massima (%) in un contatto, già relativa alla tua calibrazione.',
    AppLang.pt: 'step peak → pressão máxima (%) num contacto, já relativa à sua calibração.',
  },
  'mg_impact_var2': {
    AppLang.en: 'Weight → your weight, from Settings (only used for the kg conversion).',
    AppLang.es: 'Weight → tu peso, en Ajustes (solo se usa para la conversión a kg).',
    AppLang.fr: 'Weight → votre poids, dans Réglages (utilisé uniquement pour la conversion en kg).',
    AppLang.de: 'Weight → dein Gewicht, aus Einstellungen (nur für die kg-Umrechnung verwendet).',
    AppLang.it: 'Weight → il tuo peso, da Impostazioni (usato solo per la conversione in kg).',
    AppLang.pt: 'Weight → o seu peso, em Definições (usado apenas para a conversão em kg).',
  },
  'mg_impact_val1': {
    AppLang.en: '<60% → low',
    AppLang.es: '<60% → bajo',
    AppLang.fr: '<60% → faible',
    AppLang.de: '<60% → niedrig',
    AppLang.it: '<60% → basso',
    AppLang.pt: '<60% → baixo',
  },
  'mg_impact_val2': {
    AppLang.en: '60-99% → moderate',
    AppLang.es: '60-99% → moderado',
    AppLang.fr: '60-99% → modéré',
    AppLang.de: '60-99% → mäßig',
    AppLang.it: '60-99% → moderato',
    AppLang.pt: '60-99% → moderado',
  },
  'mg_impact_val3': {
    AppLang.en: '≥100% → high',
    AppLang.es: '≥100% → alto',
    AppLang.fr: '≥100% → élevé',
    AppLang.de: '≥100% → hoch',
    AppLang.it: '≥100% → alto',
    AppLang.pt: '≥100% → alto',
  },
  'mg_impact_nota': {
    AppLang.en: 'If you\'ve entered your weight, Impact shows converted to kg; if not, it shows as %.',
    AppLang.es: 'Si has introducido tu peso, Impacto sale convertido a kg; si no, sale en %.',
    AppLang.fr: "Si vous avez renseigné votre poids, Impact s'affiche converti en kg ; sinon, il s'affiche en %.",
    AppLang.de: 'Wenn du dein Gewicht eingetragen hast, wird Impact in kg umgerechnet angezeigt; wenn nicht, in %.',
    AppLang.it: "Se hai inserito il tuo peso, Impatto viene mostrato convertito in kg; altrimenti, in %.",
    AppLang.pt: 'Se introduziu o seu peso, o Impacto aparece convertido em kg; se não, aparece em %.',
  },
  'mg_impact_where': {
    AppLang.en: 'Session Summary, Activity Details, Home, CSV export.',
    AppLang.es: 'Resumen de sesión, Detalle de actividad, Inicio, exportación CSV.',
    AppLang.fr: 'Résumé de session, Détails d\'activité, Accueil, export CSV.',
    AppLang.de: 'Sitzungsübersicht, Aktivitätsdetails, Home, CSV-Export.',
    AppLang.it: 'Riepilogo sessione, Dettagli attività, Home, esportazione CSV.',
    AppLang.pt: 'Resumo da sessão, Detalhes da atividade, Início, exportação CSV.',
  },
  'mg_fatigue_def': {
    AppLang.en: 'How much your Impact rises from start to end.',
    AppLang.es: 'Cuánto sube tu Impacto del inicio al final.',
    AppLang.fr: "De combien votre Impact augmente du début à la fin.",
    AppLang.de: 'Wie stark dein Impact von Anfang bis Ende steigt.',
    AppLang.it: "Di quanto aumenta il tuo Impatto dall'inizio alla fine.",
    AppLang.pt: 'Quanto o seu Impacto sobe do início ao fim.',
  },
  'mg_fatigue_var1': {
    AppLang.en: 'ImpactStart → avg Impact, first third.',
    AppLang.es: 'ImpactStart → Impacto medio, primer tercio.',
    AppLang.fr: "ImpactStart → Impact moyen, premier tiers.",
    AppLang.de: 'ImpactStart → Ø Impact, erstes Drittel.',
    AppLang.it: "ImpactStart → Impatto medio, primo terzo.",
    AppLang.pt: 'ImpactStart → Impacto médio, primeiro terço.',
  },
  'mg_fatigue_var2': {
    AppLang.en: 'ImpactEnd → avg Impact, last third.',
    AppLang.es: 'ImpactEnd → Impacto medio, último tercio.',
    AppLang.fr: "ImpactEnd → Impact moyen, dernier tiers.",
    AppLang.de: 'ImpactEnd → Ø Impact, letztes Drittel.',
    AppLang.it: "ImpactEnd → Impatto medio, ultimo terzo.",
    AppLang.pt: 'ImpactEnd → Impacto médio, último terço.',
  },
  'mg_fatigue_val1': {
    AppLang.en: '<20% → stable',
    AppLang.es: '<20% → estable',
    AppLang.fr: '<20% → stable',
    AppLang.de: '<20% → stabil',
    AppLang.it: '<20% → stabile',
    AppLang.pt: '<20% → estável',
  },
  'mg_fatigue_val2': {
    AppLang.en: '≥20% → rising',
    AppLang.es: '≥20% → en aumento',
    AppLang.fr: '≥20% → en hausse',
    AppLang.de: '≥20% → steigend',
    AppLang.it: '≥20% → in aumento',
    AppLang.pt: '≥20% → a subir',
  },
  'mg_fatigue_nota': {
    AppLang.en: 'Needs a long session (≥30 samples); otherwise N/A.',
    AppLang.es: 'Necesita sesión larga (≥30 muestras); si no, N/A.',
    AppLang.fr: "Nécessite une longue session (≥30 échantillons) ; sinon N/A.",
    AppLang.de: 'Braucht eine lange Sitzung (≥30 Proben); sonst N/A.',
    AppLang.it: "Serve una sessione lunga (≥30 campioni); altrimenti N/A.",
    AppLang.pt: 'Precisa de uma sessão longa (≥30 amostras); senão N/A.',
  },
  'mg_fatigue_where': {
    AppLang.en: 'Activity Details.',
    AppLang.es: 'Detalle de actividad.',
    AppLang.fr: "Détails d'activité.",
    AppLang.de: 'Aktivitätsdetails.',
    AppLang.it: 'Dettagli attività.',
    AppLang.pt: 'Detalhes da atividade.',
  },
  'mg_strike_def': {
    AppLang.en: 'Which part of your foot lands first.',
    AppLang.es: 'Qué parte del pie toca el suelo primero.',
    AppLang.fr: 'Quelle partie du pied touche le sol en premier.',
    AppLang.de: 'Welcher Teil deines Fußes zuerst aufsetzt.',
    AppLang.it: 'Quale parte del piede tocca il suolo per prima.',
    AppLang.pt: 'Que parte do pé toca o solo primeiro.',
  },
  'mg_strike_var1': {
    AppLang.en: 'w_heel_mag → at the instant your foot first touches down, compares that reading to your own heel-press and toe-press calibration values and picks whichever it is closer to.',
    AppLang.es: 'w_heel_mag → en el instante justo del primer contacto con el suelo, compara esa lectura con tus valores de calibración de "solo talón" y "solo punta", y ve a cuál se parece más.',
    AppLang.fr: "w_heel_mag → à l'instant précis du premier contact au sol, compare cette lecture à vos valeurs d'étalonnage « talon seul » et « pointe seule », et retient celle dont elle est la plus proche.",
    AppLang.de: 'w_heel_mag → im Moment des ersten Bodenkontakts wird dieser Messwert mit deinen eigenen Kalibrierwerten für „nur Ferse“ und „nur Vorfuß“ verglichen und der näherliegende gewählt.',
    AppLang.it: "w_heel_mag → nell'istante del primo contatto con il suolo, confronta quella lettura con i tuoi valori di calibrazione \"solo tallone\" e \"solo punta\", scegliendo quello più vicino.",
    AppLang.pt: 'w_heel_mag → no instante exato do primeiro contacto com o solo, compara essa leitura com os seus valores de calibração "só calcanhar" e "só ponta", ficando com o mais próximo.',
  },
  'mg_strike_var2': {
    AppLang.en: 'Calculated independently per foot; "Both" is the average of Left and Right.',
    AppLang.es: 'Se calcula de forma independiente por pie; "Ambos" es la media de Izquierda y Derecha.',
    AppLang.fr: 'Calculé indépendamment par pied ; « Les deux » est la moyenne de Gauche et Droite.',
    AppLang.de: 'Wird unabhängig pro Fuß berechnet; „Beide“ ist der Durchschnitt aus Links und Rechts.',
    AppLang.it: 'Calcolato in modo indipendente per piede; "Entrambi" è la media di Sinistra e Destra.',
    AppLang.pt: 'Calculado de forma independente por pé; "Ambos" é a média de Esquerdo e Direito.',
  },
  'mg_strike_val1': {
    AppLang.en: '0-33% → heel (rearfoot)',
    AppLang.es: '0-33% → talón (retropié)',
    AppLang.fr: '0-33% → talon (arrière-pied)',
    AppLang.de: '0-33% → Ferse (Rückfuß)',
    AppLang.it: '0-33% → tallone (retropiede)',
    AppLang.pt: '0-33% → calcanhar (retropé)',
  },
  'mg_strike_val2': {
    AppLang.en: '34-66% → midfoot',
    AppLang.es: '34-66% → mediopié',
    AppLang.fr: '34-66% → médio-pied',
    AppLang.de: '34-66% → Mittelfuß',
    AppLang.it: '34-66% → mesopiede',
    AppLang.pt: '34-66% → mediopé',
  },
  'mg_strike_val3': {
    AppLang.en: '67-100% → forefoot',
    AppLang.es: '67-100% → antepié',
    AppLang.fr: '67-100% → avant-pied',
    AppLang.de: '67-100% → Vorfuß',
    AppLang.it: '67-100% → avampiede',
    AppLang.pt: '67-100% → antepé',
  },
  'mg_strike_nota': {
    AppLang.en: 'Left/Right are independent: one can show N/A.',
    AppLang.es: 'Izquierdo/Derecho son independientes: uno puede dar N/A.',
    AppLang.fr: "Gauche/Droite sont indépendants : l'un peut afficher N/A.",
    AppLang.de: 'Links/Rechts sind unabhängig: einer kann N/A zeigen.',
    AppLang.it: 'Sinistro/Destro sono indipendenti: uno può mostrare N/A.',
    AppLang.pt: 'Esquerdo/Direito são independentes: um pode mostrar N/A.',
  },
  'mg_strike_where': {
    AppLang.en: 'Activity Details, CSV export.',
    AppLang.es: 'Detalle de actividad, exportación CSV.',
    AppLang.fr: "Détails d'activité, export CSV.",
    AppLang.de: 'Aktivitätsdetails, CSV-Export.',
    AppLang.it: 'Dettagli attività, esportazione CSV.',
    AppLang.pt: 'Detalhes da atividade, exportação CSV.',
  },
  'mg_performance_def': {
    AppLang.en: 'Single score (0-100) combining 3 metrics.',
    AppLang.es: 'Puntuación única (0-100) que combina 3 métricas.',
    AppLang.fr: "Score unique (0-100) combinant 3 métriques.",
    AppLang.de: 'Einzelwert (0-100), der 3 Metriken kombiniert.',
    AppLang.it: "Punteggio unico (0-100) che combina 3 metriche.",
    AppLang.pt: 'Pontuação única (0-100) que combina 3 métricas.',
  },
  'mg_performance_var1': {
    AppLang.en: 'PenBalance → the imbalance % itself (0% = ideal), same as Balance everywhere else.',
    AppLang.es: 'PenBalance → el propio % de desequilibrio (0% = ideal), igual que Equilibrio en el resto de la app.',
    AppLang.fr: "PenBalance → le % de déséquilibre lui-même (0% = idéal), comme Équilibre partout ailleurs.",
    AppLang.de: 'PenBalance → der %-Wert der Abweichung selbst (0% = ideal), genau wie Balance überall sonst.',
    AppLang.it: "PenBalance → la stessa % di squilibrio (0% = ideale), come Equilibrio nel resto dell'app.",
    AppLang.pt: 'PenBalance → a própria % de desequilíbrio (0% = ideal), igual ao Equilíbrio no resto da app.',
  },
  'mg_performance_var2': {
    AppLang.en: 'PenFatigue → the Fatigue Index itself.',
    AppLang.es: 'PenFatigue → el propio Índice de fatiga.',
    AppLang.fr: "PenFatigue → l'Indice de fatigue lui-même.",
    AppLang.de: 'PenFatigue → der Ermüdungsindex selbst.',
    AppLang.it: "PenFatigue → l'Indice di affaticamento stesso.",
    AppLang.pt: 'PenFatigue → o próprio Índice de fadiga.',
  },
  'mg_performance_var3': {
    AppLang.en: 'PenStride → how far Stride Ratio is from 100%.',
    AppLang.es: 'PenStride → cuánto se aleja el ratio de zancada de 100%.',
    AppLang.fr: "PenStride → écart du ratio de foulée par rapport à 100%.",
    AppLang.de: 'PenStride → Abweichung des Schrittverhältnisses von 100%.',
    AppLang.it: "PenStride → quanto il rapporto del passo si allontana dal 100%.",
    AppLang.pt: 'PenStride → quão longe o rácio de passada está de 100%.',
  },
  'mg_performance_val1': {
    AppLang.en: '≥85 → excellent',
    AppLang.es: '≥85 → excelente',
    AppLang.fr: '≥85 → excellent',
    AppLang.de: '≥85 → hervorragend',
    AppLang.it: '≥85 → eccellente',
    AppLang.pt: '≥85 → excelente',
  },
  'mg_performance_val2': {
    AppLang.en: '70-84 → good',
    AppLang.es: '70-84 → bueno',
    AppLang.fr: '70-84 → bon',
    AppLang.de: '70-84 → gut',
    AppLang.it: '70-84 → buono',
    AppLang.pt: '70-84 → bom',
  },
  'mg_performance_val3': {
    AppLang.en: '50-69 → fair',
    AppLang.es: '50-69 → aceptable',
    AppLang.fr: '50-69 → correct',
    AppLang.de: '50-69 → ausreichend',
    AppLang.it: '50-69 → sufficiente',
    AppLang.pt: '50-69 → aceitável',
  },
  'mg_performance_val4': {
    AppLang.en: '<50 → needs work',
    AppLang.es: '<50 → mejorable',
    AppLang.fr: '<50 → à améliorer',
    AppLang.de: '<50 → verbesserungswürdig',
    AppLang.it: '<50 → da migliorare',
    AppLang.pt: '<50 → a melhorar',
  },
  'mg_performance_nota': {
    AppLang.en: 'Missing metrics are skipped, not penalized.',
    AppLang.es: 'Si falta alguna de las 3, se ignora (no penaliza).',
    AppLang.fr: "Les métriques manquantes sont ignorées, pas pénalisées.",
    AppLang.de: 'Fehlende Metriken werden übersprungen, nicht bestraft.',
    AppLang.it: "Le metriche mancanti vengono ignorate, non penalizzate.",
    AppLang.pt: 'Métricas em falta são ignoradas, não penalizadas.',
  },
  'mg_performance_where': {
    AppLang.en: 'Activity Details.',
    AppLang.es: 'Detalle de actividad.',
    AppLang.fr: "Détails d'activité.",
    AppLang.de: 'Aktivitätsdetails.',
    AppLang.it: 'Dettagli attività.',
    AppLang.pt: 'Detalhes da atividade.',
  },
  'mg_cadence_def': {
    AppLang.en: 'Steps per minute, session average.',
    AppLang.es: 'Pasos por minuto, media de la sesión.',
    AppLang.fr: "Pas par minute, moyenne de la session.",
    AppLang.de: 'Schritte pro Minute, Sitzungsdurchschnitt.',
    AppLang.it: "Passi al minuto, media della sessione.",
    AppLang.pt: 'Passos por minuto, média da sessão.',
  },
  'mg_cadence_where': {
    AppLang.en: 'Live Analysis, Activity Details, Home quick metrics, Export Metrics.',
    AppLang.es: 'Análisis en vivo, Detalle de actividad, Métricas rápidas de Inicio, Exportar métricas.',
    AppLang.fr: "Analyse en direct, Détails d'activité, Métriques rapides Accueil, Exporter les métriques.",
    AppLang.de: 'Live-Analyse, Aktivitätsdetails, Home-Schnellübersicht, Metriken exportieren.',
    AppLang.it: 'Analisi live, Dettagli attività, Metriche rapide Home, Esporta metriche.',
    AppLang.pt: 'Análise ao vivo, Detalhes da atividade, Métricas rápidas do Início, Exportar métricas.',
  },
  'mg_stride_def': {
    AppLang.en: "Your real stride vs. what's expected for your height.",
    AppLang.es: 'Tu zancada real comparada con la esperada para tu altura.',
    AppLang.fr: "Votre foulée réelle vs. celle attendue pour votre taille.",
    AppLang.de: 'Deine reale Schrittlänge vs. die für deine Größe erwartete.',
    AppLang.it: "Il tuo passo reale vs. quello atteso per la tua altezza.",
    AppLang.pt: 'A sua passada real vs. a esperada para a sua altura.',
  },
  'mg_stride_var1': {
    AppLang.en: 'k → 0.415 (walk) or 0.50 (run/trail).',
    AppLang.es: 'k → 0,415 (caminar) o 0,50 (correr/trail).',
    AppLang.fr: "k → 0,415 (marche) ou 0,50 (course/trail).",
    AppLang.de: 'k → 0,415 (Gehen) oder 0,50 (Laufen/Trail).',
    AppLang.it: "k → 0,415 (camminata) o 0,50 (corsa/trail).",
    AppLang.pt: 'k → 0,415 (caminhada) ou 0,50 (corrida/trail).',
  },
  'mg_stride_val1': {
    AppLang.en: '100% → exactly as expected',
    AppLang.es: '100% → justo lo esperado',
    AppLang.fr: '100% → exactement comme attendu',
    AppLang.de: '100% → genau wie erwartet',
    AppLang.it: '100% → esattamente come previsto',
    AppLang.pt: '100% → exatamente o esperado',
  },
  'mg_stride_val2': {
    AppLang.en: '<100% → shorter stride',
    AppLang.es: '<100% → zancada más corta',
    AppLang.fr: '<100% → foulée plus courte',
    AppLang.de: '<100% → kürzerer Schritt',
    AppLang.it: '<100% → passo più corto',
    AppLang.pt: '<100% → passada mais curta',
  },
  'mg_stride_val3': {
    AppLang.en: '>100% → longer stride',
    AppLang.es: '>100% → zancada más larga',
    AppLang.fr: '>100% → foulée plus longue',
    AppLang.de: '>100% → längerer Schritt',
    AppLang.it: '>100% → passo più lungo',
    AppLang.pt: '>100% → passada mais longa',
  },
  'mg_stride_nota': {
    AppLang.en: 'k comes from Hoeger et al. (2008), "One-Mile Step Count at Walking and Running Speeds", ACSM\'s Health & Fitness Journal.',
    AppLang.es: 'k viene de Hoeger et al. (2008), "One-Mile Step Count at Walking and Running Speeds", ACSM\'s Health & Fitness Journal.',
    AppLang.fr: 'k vient de Hoeger et al. (2008), « One-Mile Step Count at Walking and Running Speeds », ACSM\'s Health & Fitness Journal.',
    AppLang.de: 'k stammt von Hoeger et al. (2008), „One-Mile Step Count at Walking and Running Speeds“, ACSM\'s Health & Fitness Journal.',
    AppLang.it: 'k viene da Hoeger et al. (2008), "One-Mile Step Count at Walking and Running Speeds", ACSM\'s Health & Fitness Journal.',
    AppLang.pt: 'k vem de Hoeger et al. (2008), "One-Mile Step Count at Walking and Running Speeds", ACSM\'s Health & Fitness Journal.',
  },
  'mg_stride_where': {
    AppLang.en: 'Activity Details.',
    AppLang.es: 'Detalle de actividad.',
    AppLang.fr: "Détails d'activité.",
    AppLang.de: 'Aktivitätsdetails.',
    AppLang.it: 'Dettagli attività.',
    AppLang.pt: 'Detalhes da atividade.',
  },
  'mg_heel_metatarsal_title': {
    AppLang.en: 'Heel / Metatarsal breakdown',
    AppLang.es: 'Desglose talón / metatarso',
    AppLang.fr: 'Répartition talon / métatarse',
    AppLang.de: 'Fersen-/Mittelfuß-Aufschlüsselung',
    AppLang.it: 'Ripartizione tallone / metatarso',
    AppLang.pt: 'Detalhe calcanhar / metatarso',
  },
  'mg_heel_metatarsal_def': {
    AppLang.en: 'Estimated pressure split: heel vs. metatarsal.',
    AppLang.es: 'Reparto estimado de presión: talón vs. metatarso.',
    AppLang.fr: 'Répartition estimée : talon vs. métatarse.',
    AppLang.de: 'Geschätzte Aufteilung: Ferse vs. Mittelfuß.',
    AppLang.it: 'Ripartizione stimata: tallone vs. metatarso.',
    AppLang.pt: 'Divisão estimada: calcanhar vs. metatarso.',
  },
  'mg_heel_metatarsal_var1': {
    AppLang.en: 'w_heel → fraction painted as "heel" on the map.',
    AppLang.es: 'w_heel → fracción pintada como "talón" en el mapa.',
    AppLang.fr: 'w_heel → fraction peinte comme « talon » sur la carte.',
    AppLang.de: 'w_heel → als „Ferse“ in der Karte eingefärbter Anteil.',
    AppLang.it: 'w_heel → frazione colorata come "tallone" sulla mappa.',
    AppLang.pt: 'w_heel → fração pintada como "calcanhar" no mapa.',
  },
  'mg_heel_metatarsal_var2': {
    AppLang.en: 'Heel Strike starts the moment pressure crosses the 15% contact threshold; w_heel stays at 1.0 for as long as that phase lasts.',
    AppLang.es: 'Heel Strike empieza en cuanto la presión cruza el umbral de contacto del 15%; w_heel se queda en 1.0 mientras dure esa fase.',
    AppLang.fr: "Heel Strike commence dès que la pression franchit le seuil de contact de 15% ; w_heel reste à 1.0 tant que dure cette phase.",
    AppLang.de: 'Heel Strike beginnt, sobald der Druck die Kontaktschwelle von 15% überschreitet; w_heel bleibt bei 1.0, solange diese Phase andauert.',
    AppLang.it: "Heel Strike inizia nel momento in cui la pressione supera la soglia di contatto del 15%; w_heel resta a 1.0 per tutta la durata di quella fase.",
    AppLang.pt: 'Heel Strike começa no momento em que a pressão ultrapassa o limiar de contacto de 15%; w_heel mantém-se em 1.0 enquanto durar essa fase.',
  },
  'mg_heel_metatarsal_val1': {
    AppLang.en: 'Heel Strike → right at touchdown',
    AppLang.es: 'Heel Strike → justo al pisar',
    AppLang.fr: "Heel Strike → juste à l'appui",
    AppLang.de: 'Heel Strike → direkt beim Aufsetzen',
    AppLang.it: 'Heel Strike → appena si appoggia',
    AppLang.pt: 'Heel Strike → mesmo ao pisar',
  },
  'mg_heel_metatarsal_val2': {
    AppLang.en: 'Midstance → flat foot',
    AppLang.es: 'Midstance → pie plano',
    AppLang.fr: 'Midstance → pied à plat',
    AppLang.de: 'Midstance → flacher Fuß',
    AppLang.it: 'Midstance → piede piatto',
    AppLang.pt: 'Midstance → pé plano',
  },
  'mg_heel_metatarsal_val3': {
    AppLang.en: 'Propulsion/Swing → push-off or airborne',
    AppLang.es: 'Propulsion/Swing → empuje o en el aire',
    AppLang.fr: "Propulsion/Swing → poussée ou en l'air",
    AppLang.de: 'Propulsion/Swing → Abstoß oder in der Luft',
    AppLang.it: 'Propulsion/Swing → spinta o in aria',
    AppLang.pt: 'Propulsion/Swing → impulso ou no ar',
  },
  'mg_heel_metatarsal_nota': {
    AppLang.en: 'Estimated from the gait phase, not measured (only 1 sensor per foot): heel/arch/forefoot light up by w_heel, not by real pressure there.',
    AppLang.es: 'Se estima según la fase de marcha, no se mide (solo hay 1 sensor por pie): talón/arco/metatarso se encienden según w_heel, no por presión real ahí.',
    AppLang.fr: "Estimé selon la phase de marche, pas mesuré (un seul capteur par pied) : talon/voûte/avant-pied s'allument selon w_heel, pas par une pression réelle à cet endroit.",
    AppLang.de: 'Geschätzt anhand der Gangphase, nicht gemessen (nur 1 Sensor pro Fuß): Ferse/Gewölbe/Vorfuß leuchten je nach w_heel, nicht durch echten Druck dort.',
    AppLang.it: "Stimata in base alla fase del passo, non misurata (un solo sensore per piede): tallone/arco/avampiede si accendono in base a w_heel, non per pressione reale lì.",
    AppLang.pt: 'Estimado a partir da fase de marcha, não medido (só 1 sensor por pé): calcanhar/arco/antepé acendem consoante o w_heel, não por pressão real ali.',
  },
  'mg_heel_metatarsal_where': {
    AppLang.en: 'Live Analysis, Activity Details.',
    AppLang.es: 'Análisis en vivo, Detalle de actividad.',
    AppLang.fr: "Analyse en direct, Détails d'activité.",
    AppLang.de: 'Live-Analyse, Aktivitätsdetails.',
    AppLang.it: "Analisi live, Dettagli attività.",
    AppLang.pt: 'Análise ao vivo, Detalhes da atividade.',
  },
  'about_insights_title': {
    AppLang.en: 'About Insights',
    AppLang.es: 'Sobre Información',
    AppLang.fr: 'À propos des analyses',
    AppLang.de: 'Über Erkenntnisse',
    AppLang.it: 'Informazioni sugli approfondimenti',
    AppLang.pt: 'Sobre as informações',
  },
  'about_insights_intro': {
    AppLang.en: "The Insights text and the rating (Excellent/Good/Fair/Needs improvement) on Activity Details are both generated from your session's real numbers with fixed rules:",
    AppLang.es: 'El texto de Información y la valoración (Excelente/Bueno/Aceptable/Necesita mejorar) en Detalle de actividad se generan a partir de los números reales de tu sesión con reglas fijas:',
    AppLang.fr: "Le texte des analyses et l'appréciation (Excellent/Bon/Correct/À améliorer) dans Détails d'activité sont générés à partir des chiffres réels de votre session avec des règles fixes :",
    AppLang.de: 'Der Erkenntnistext und die Bewertung (Ausgezeichnet/Gut/Befriedigend/Verbesserungswürdig) in den Aktivitätsdetails werden beide anhand fester Regeln aus den echten Zahlen deiner Sitzung erzeugt:',
    AppLang.it: "Il testo degli approfondimenti e la valutazione (Eccellente/Buono/Sufficiente/Da migliorare) nei Dettagli attività vengono generati entrambi dai numeri reali della tua sessione con regole fisse:",
    AppLang.pt: 'O texto de Informações e a avaliação (Excelente/Bom/Razoável/Precisa de melhorar) nos Detalhes da atividade são gerados a partir dos números reais da sua sessão com regras fixas:',
  },
  'about_insights_rule_1': {
    AppLang.en: 'Imbalance <15% → "well balanced".',
    AppLang.es: 'Desequilibrio <15% → "bien equilibrado".',
    AppLang.fr: 'Déséquilibre <15% → « bien équilibré ».',
    AppLang.de: 'Ungleichgewicht <15% → „gut ausgeglichen“.',
    AppLang.it: 'Squilibrio <15% → "ben bilanciato".',
    AppLang.pt: 'Desequilíbrio <15% → "bem equilibrado".',
  },
  'about_insights_rule_2': {
    AppLang.en: 'Imbalance ≥15% → names which foot carried more.',
    AppLang.es: 'Desequilibrio ≥15% → indica qué pie soportó más.',
    AppLang.fr: "Déséquilibre ≥15% → indique quel pied a le plus porté.",
    AppLang.de: 'Ungleichgewicht ≥15% → nennt, welcher Fuß mehr trug.',
    AppLang.it: 'Squilibrio ≥15% → indica quale piede ha sostenuto di più.',
    AppLang.pt: 'Desequilíbrio ≥15% → indica qual pé suportou mais.',
  },
  'about_insights_rule_3': {
    AppLang.en: 'Fatigue Index ≥ 20% → impact rose noticeably by the end.',
    AppLang.es: 'Índice de fatiga ≥ 20% → el impacto aumentó notablemente al final.',
    AppLang.fr: "Indice de fatigue ≥ 20% → l'impact a augmenté nettement vers la fin.",
    AppLang.de: 'Ermüdungsindex ≥ 20% → Impact stieg zum Ende hin deutlich an.',
    AppLang.it: "Indice di affaticamento ≥ 20% → l'impatto è aumentato notevolmente verso la fine.",
    AppLang.pt: 'Índice de fadiga ≥ 20% → o impacto aumentou visivelmente perto do fim.',
  },
  'about_insights_rule_4': {
    AppLang.en: 'Fatigue Index < 20% → impact stayed consistent.',
    AppLang.es: 'Índice de fatiga < 20% → el impacto se mantuvo constante.',
    AppLang.fr: "Indice de fatigue < 20% → l'impact est resté constant.",
    AppLang.de: 'Ermüdungsindex < 20% → Impact blieb konstant.',
    AppLang.it: "Indice di affaticamento < 20% → l'impatto è rimasto costante.",
    AppLang.pt: 'Índice de fadiga < 20% → o impacto manteve-se constante.',
  },
  'about_insights_rule_5': {
    AppLang.en: 'Stride ratio above 1.15 or below 0.85 → flags a longer/shorter stride than expected.',
    AppLang.es: 'Ratio de zancada por encima de 1,15 o por debajo de 0,85 → señala una zancada más larga/corta de lo esperado.',
    AppLang.fr: "Ratio de foulée au-dessus de 1,15 ou en dessous de 0,85 → signale une foulée plus longue/courte que prévu.",
    AppLang.de: 'Schrittverhältnis über 1,15 oder unter 0,85 → meldet eine längere/kürzere Schrittlänge als erwartet.',
    AppLang.it: "Rapporto del passo sopra 1,15 o sotto 0,85 → segnala un passo più lungo/corto del previsto.",
    AppLang.pt: 'Rácio de passada acima de 1,15 ou abaixo de 0,85 → assinala uma passada mais longa/curta do que o esperado.',
  },
  'about_insights_rule_6': {
    AppLang.en: 'Performance Score ≥85/≥70/≥50/below → rated Excellent/Good/Fair/Needs improvement.',
    AppLang.es: 'Puntuación de Rendimiento ≥85/≥70/≥50/por debajo → valoración Excelente/Bueno/Aceptable/Necesita mejorar.',
    AppLang.fr: "Score de performance ≥85/≥70/≥50/en dessous → appréciation Excellent/Bon/Correct/À améliorer.",
    AppLang.de: 'Leistungspunktzahl ≥85/≥70/≥50/darunter → Bewertung Ausgezeichnet/Gut/Befriedigend/Verbesserungswürdig.',
    AppLang.it: "Punteggio di Rendimento ≥85/≥70/≥50/sotto → valutazione Eccellente/Buono/Sufficiente/Da migliorare.",
    AppLang.pt: 'Pontuação de Desempenho ≥85/≥70/≥50/abaixo → avaliação Excelente/Bom/Razoável/Precisa de melhorar.',
  },
  'got_it_button': {
    AppLang.en: 'Got it',
    AppLang.es: 'Entendido',
    AppLang.fr: "J'ai compris",
    AppLang.de: 'Verstanden',
    AppLang.it: 'Capito',
    AppLang.pt: 'Percebi',
  },
};

// Mixin para pantallas que usan tr(): reconstruye al cambiar de idioma
mixin IdiomaListenerMixin<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    appLang.addListener(_onLangChangeMixin);
  }

  void _onLangChangeMixin() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    appLang.removeListener(_onLangChangeMixin);
    super.dispose();
  }
}

// Cae a inglés y luego a la propia clave si falta la traducción
String tr(String clave) {
  final entradas = _traducciones[clave];
  if (entradas == null) {
    return clave;
  }
  return entradas[appLang.value] ?? entradas[AppLang.en] ?? clave;
}

const Color kBg = Color(0xFF0D1117);
const Color kCard = Color(0xFF1A1F2E);
const Color kOrange = Color(0xFFFF8A00);
const Color kRed = Color(0xFFFF3D57);
const Color kYellow = Color(0xFFFFC107);
const Color kTeal = Color(0xFF00D9C0);
const Color kPurple = Color(0xFF8B5CF6);
const Color kGray = Color(0xFF6B7280);
const Color kGrayDark = Color(0xFF374151);

LinearGradient get kGradient => const LinearGradient(
      colors: [kOrange, kRed],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );

LinearGradient get kGradientFull => const LinearGradient(
      colors: [kOrange, kRed, kYellow],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

// ---- TRANSICIÓN DE PANTALLA ----
// Reemplazo de MaterialPageRoute con fundido + desplazamiento lateral
Route<T> gogaitRoute<T>({required WidgetBuilder builder}) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) =>
        builder(context),
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curva = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic);
      return FadeTransition(
        opacity: curva,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero)
              .animate(curva),
          child: child,
        ),
      );
    },
  );
}

// ---- MODELS ----
// Datos del usuario logueado: perfil, medidas corporales y preferencias.
class Usuario {
  String email, nombre, apellido, genero, cumpleanos, contrasena, arco;
  double altura, peso, shoeSize;
  String? fotoPath, patologia;
  Usuario({
    required this.email,
    required this.nombre,
    required this.apellido,
    required this.genero,
    required this.contrasena,
    required this.altura,
    required this.peso,
    required this.cumpleanos,
    required this.shoeSize,
    required this.arco,
    this.fotoPath,
    this.patologia,
  });
}

// Sin altura/peso reales no se puede calcular Impacto en kg ni Stride Ratio
bool _perfilIncompleto(Usuario? u) =>
    u == null || u.altura < 140 || u.peso < 40;

// Sesión guardada en el historial (running, walking, trail...) con sus métricas y, opcionalmente, muestras crudas
class SesionActividad {
  String id, titulo, descripcion, tipo, fecha, hora, duracion;
  // presionMetaIzq/presionTalonIzq quedan a 0 si no hubo datos del pie izquierdo (ver tieneDatosPieIzquierdo)
  final double presionMeta, presionTalon;
  final double presionMetaIzq, presionTalonIzq;
  final int pasos;
  final double cadencia; // pasos/min medios de la sesión
  final double distanciaKm; // medida por GPS
  final double balance, impacto; // ver calcularBalance/calcularImpacto
  final double impactoIzq;
  final double impactoKg; // ver impactoAKg, 0 si no había peso registrado
  final double zancadaRatio; // ver ratioZancada, 0 si faltaba algún dato
  // strikeIndex: 0=talón, 50=centrado, 100=antepié; 0 también si no hay contactos medibles
  final double strikeIndexDer, strikeIndexIzq;
  // distinguen "0 real" de "no medible" en cada métrica
  final bool tieneBalance, tieneFatiga, tieneStrikeDer, tieneStrikeIzq;
  final bool tieneImpacto;
  final double fatiga;
  final List<double> tramosFatiga;
  // no es final: se vacía al purgar muestras crudas antiguas (ver purgarDatosCrudosAntiguos)
  List<Map<String, dynamic>> datosSesion;
  // una entrada por posición GPS, 'seg' comparte eje temporal con datosSesion
  final List<Map<String, dynamic>> recorrido;
  // calibración de cada plantilla en el momento de guardar, null si no llegó a calibrarse
  final double? adcReposoDer, adcCargaDer, adcTalonDer, adcPuntaDer;
  final double? adcReposoIzq, adcCargaIzq, adcTalonIzq, adcPuntaIzq;
  SesionActividad({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.tipo,
    required this.fecha,
    required this.hora,
    required this.duracion,
    required this.presionMeta,
    required this.presionTalon,
    this.presionMetaIzq = 0,
    this.presionTalonIzq = 0,
    this.pasos = 0,
    this.cadencia = 0,
    this.distanciaKm = 0,
    this.balance = 0,
    this.impacto = 0,
    this.impactoIzq = 0,
    this.impactoKg = 0,
    this.zancadaRatio = 0,
    this.strikeIndexDer = 0,
    this.strikeIndexIzq = 0,
    this.tieneBalance = false,
    this.tieneFatiga = false,
    this.tieneStrikeDer = false,
    this.tieneStrikeIzq = false,
    this.tieneImpacto = false,
    this.fatiga = 0,
    this.tramosFatiga = const [0, 0, 0],
    this.datosSesion = const [],
    this.recorrido = const [],
    this.adcReposoDer,
    this.adcCargaDer,
    this.adcTalonDer,
    this.adcPuntaDer,
    this.adcReposoIzq,
    this.adcCargaIzq,
    this.adcTalonIzq,
    this.adcPuntaIzq,
  });
}

// Un sensor por plantilla mide talón+metatarso como una sola señal: solo da balance izq/der y Heel/Metatarsal (eje medial/lateral no medible con este hardware)

// umbral de contacto compartido por toda la app; en pruebas el ruido en Swing llegó a ~14,9, quizá subir a 18.0
const kUmbralContacto = 15.0;

// balance: 0-100 (50=simétrico). Sin muestras del pie izq. devuelve 50 en vez de fingir un reparto real
double calcularBalance(List<Map<String, dynamic>> datosSesion) {
  var sumaIzq = 0.0, sumaDer = 0.0;
  for (final d in datosSesion) {
    sumaIzq +=
        (d['talonIzq'] as num).toDouble() + (d['metaIzq'] as num).toDouble();
    sumaDer +=
        (d['talonDer'] as num).toDouble() + (d['metaDer'] as num).toDouble();
  }
  if (sumaIzq <= 0) {
    return 50;
  }
  return (100 * sumaDer / (sumaIzq + sumaDer)).clamp(0.0, 100.0);
}

// sin muestras del pie izq. el balance es el valor neutro, no un dato medido
bool tieneDatosPieIzquierdo(List<Map<String, dynamic>> datosSesion) =>
    datosSesion.any((d) =>
        (d['talonIzq'] as num).toDouble() != 0 ||
        (d['metaIzq'] as num).toDouble() != 0);

// impacto: 0-100, media del pico de presión de cada contacto por encima del umbral
double calcularImpacto(List<Map<String, dynamic>> datosSesion, Pie pie) {
  final sufijo = pie == Pie.derecha ? 'Der' : 'Izq';
  final picos = <double>[];
  var enContacto = false;
  var pico = 0.0;
  for (final d in datosSesion) {
    final presion = (d['talon$sufijo'] as num).toDouble() +
        (d['meta$sufijo'] as num).toDouble();
    if (presion >= kUmbralContacto) {
      if (!enContacto || presion > pico) {
        pico = presion;
      }
      enContacto = true;
    } else if (enContacto) {
      picos.add(pico);
      enContacto = false;
    }
  }
  if (enContacto) {
    picos.add(pico);
  }
  if (picos.isEmpty) {
    return 0;
  }
  return picos.reduce((a, b) => a + b) / picos.length;
}

// sesiones grabadas antes de guardar faseDer/faseIzq no tienen strikeIndex: 0 aquí significa "no medible", no talón puro
bool tieneDatosStrikeIndex(List<Map<String, dynamic>> datosSesion, Pie pie) {
  final sufijo = pie == Pie.derecha ? 'Der' : 'Izq';
  return datosSesion.any((d) => d['fase$sufijo'] != null);
}

// strikeIndex: 0-100 (0=talón, 50=centrado, 100=antepié), medido en la transición Swing->Heel Strike.
// Usa wMagTalon (vs. calibración talón/punta) y no _pesoTalon, que en Heel Strike siempre daría "talón puro".
double calcularStrikeIndex(List<Map<String, dynamic>> datosSesion, Pie pie) {
  final sufijo = pie == Pie.derecha ? 'Der' : 'Izq';
  final indices = <double>[];
  String? faseAnterior;
  for (final d in datosSesion) {
    final fase = d['fase$sufijo'] as String?;
    if (fase == 'Heel Strike' && faseAnterior == 'Swing') {
      final wMagTalon = (d['wMagTalon$sufijo'] as num?)?.toDouble();
      if (wMagTalon != null) {
        indices.add(100 * (1 - wMagTalon));
      }
    }
    faseAnterior = fase;
  }
  if (indices.isEmpty) {
    return 0;
  }
  return indices.reduce((a, b) => a + b) / indices.length;
}

// media de ambos pies en un tramo, igual que el badge "Both" de Impact en la UI
double _impactoMedioTramo(List<Map<String, dynamic>> tramo) {
  final der = calcularImpacto(tramo, Pie.derecha);
  final izq = calcularImpacto(tramo, Pie.izquierda);
  return (der + izq) / 2;
}

// menos de 30 muestras no dan 3 tramos con datos suficientes para fatiga fiable
const int _kMinMuestrasFatiga = 30;

bool tieneDatosFatiga(List<Map<String, dynamic>> datosSesion) =>
    datosSesion.length >= _kMinMuestrasFatiga &&
    _impactoMedioTramo(
            datosSesion.sublist(0, datosSesion.length ~/ 3)) >
        0;

// fatiga: % de subida del impacto medio del último tercio vs. el primero; puede salir negativo
double calcularFatiga(List<Map<String, dynamic>> datosSesion) {
  if (!tieneDatosFatiga(datosSesion)) {
    return 0;
  }
  final tercio = datosSesion.length ~/ 3;
  final inicio = datosSesion.sublist(0, tercio);
  final fin = datosSesion.sublist(datosSesion.length - tercio);
  final impactoInicio = _impactoMedioTramo(inicio);
  final impactoFin = _impactoMedioTramo(fin);
  return 100 * (impactoFin - impactoInicio) / impactoInicio;
}

// los 3 valores de impacto medio (inicio/mitad/fin) del gráfico de fatiga
List<double> tramosFatiga(List<Map<String, dynamic>> datosSesion) {
  if (!tieneDatosFatiga(datosSesion)) {
    return const [0, 0, 0];
  }
  final tercio = datosSesion.length ~/ 3;
  return [
    _impactoMedioTramo(datosSesion.sublist(0, tercio)),
    _impactoMedioTramo(datosSesion.sublist(tercio, tercio * 2)),
    _impactoMedioTramo(datosSesion.sublist(tercio * 2)),
  ];
}

// performanceScore: 0-100, penalización media de balance/fatiga/zancadaRatio; null si ninguna disponible
double? calcularPerformanceScore({
  required double balance,
  required bool tieneBalance,
  required double fatiga,
  required bool tieneFatiga,
  required double? zancadaRatio,
}) {
  final penalizaciones = <double>[];
  if (tieneBalance) {
    penalizaciones.add((balance - 50).abs() * 2);
  }
  if (tieneFatiga) {
    penalizaciones.add(fatiga);
  }
  if (zancadaRatio != null && zancadaRatio > 0) {
    penalizaciones.add((zancadaRatio - 1.0).abs() * 100);
  }
  if (penalizaciones.isEmpty) {
    return null;
  }
  final penalizacionMedia =
      penalizaciones.reduce((a, b) => a + b) / penalizaciones.length;
  return (100 - penalizacionMedia).clamp(0.0, 100.0);
}

// insights generados con reglas fijas sobre las métricas reales, sin IA ni relleno
String generarInsights(SesionActividad s) {
  final frases = <String>[];
  if (s.tieneBalance) {
    // mismo umbral que colorDesequilibrio (15%): desviación = desequilibrio/2
    final desviacion = (s.balance - 50).abs();
    if (desviacion < 7.5) {
      frases.add(tr('insight_balanced'));
    } else {
      final lado = s.balance > 50 ? tr('side_right') : tr('side_left');
      frases.add(tr('insight_favors_side')
          .replaceAll('{side}', lado.toLowerCase())
          .replaceAll('{right}', '${s.balance.round()}')
          .replaceAll('{left}', '${(100 - s.balance).round()}'));
    }
  }
  if (s.tieneFatiga) {
    final fatiga = s.fatiga;
    frases.add(fatiga >= 20
        ? tr('insight_fatigue_rising')
        : tr('insight_fatigue_stable'));
  }
  if (s.zancadaRatio > 1.15) {
    frases.add(tr('insight_stride_longer'));
  } else if (s.zancadaRatio > 0 && s.zancadaRatio < 0.85) {
    frases.add(tr('insight_stride_shorter'));
  }
  if (frases.isEmpty) {
    return tr('insight_not_enough_data');
  }
  return frases.join(' ');
}

// 100% de calibración = todo el peso apoyado, así que impacto/100 × peso ≈ kg en el pico
double impactoAKg(double impacto, double pesoKg) {
  if (pesoKg <= 0) {
    return 0;
  }
  return impacto / 100 * pesoKg;
}

// coeficientes de Hoeger et al. (2008, ACSM's Health & Fitness Journal): 0,415 caminar, 0,50 correr
double zancadaEsperadaM(double alturaCm, String tipoActividad) {
  final coef = tipoActividad == 'walking' ? 0.415 : 0.50;
  return (alturaCm / 100) * coef;
}

// ratio zancada real/esperada, 1.0 = lo esperado; null si falta altura, pasos o distancia
double? ratioZancada(
    double distanciaKm, int pasos, double alturaCm, String tipoActividad) {
  if (alturaCm <= 0 || pasos <= 0 || distanciaKm <= 0) {
    return null;
  }
  final esperadaM = zancadaEsperadaM(alturaCm, tipoActividad);
  if (esperadaM <= 0) {
    return null;
  }
  final zancadaRealM = (distanciaKm * 1000) / pasos;
  return zancadaRealM / esperadaM;
}

// se persiste como "DD/MM/YYYY", se muestra como "June 25, 2026"
String fechaNacAGuardar(DateTime fecha) =>
    '${fecha.day.toString().padLeft(2, '0')}/'
    '${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';

String fechaNacAMostrar(DateTime? fecha) => fecha == null
    ? '—'
    : '${tr('month_${fecha.month}')} ${fecha.day}, ${fecha.year}';

// "Member since June 2026" a partir de currentUser.metadata.creationTime
String miembroDesde() {
  final creado = FirebaseAuth.instance.currentUser?.metadata.creationTime;
  if (creado == null) {
    return '';
  }
  return tr('member_since')
      .replaceAll('{month}', tr('month_${creado.month}'))
      .replaceAll('{year}', '${creado.year}');
}

// reconstruye el DateTime desde el formato de fechaNacAGuardar
DateTime? fechaNacDesdeGuardado(String guardado) {
  final parts = guardado.split('/');
  if (parts.length != 3) {
    return null;
  }
  return DateTime.tryParse('${parts[2]}-${parts[1].padLeft(2, '0')}-'
      '${parts[0].padLeft(2, '0')}');
}

// solo-calendario: el modo teclado "MM/DD/YYYY" confunde con guiones
Future<DateTime?> elegirFechaNacimiento(
        BuildContext context, DateTime? actual) =>
    showDatePicker(
        context: context,
        initialDate: actual ?? DateTime(1990),
        firstDate: DateTime(1940),
        lastDate: DateTime.now(),
        initialEntryMode: DatePickerEntryMode.calendarOnly,
        builder: (ctx, child) => Theme(
            data: ThemeData.dark().copyWith(
                colorScheme:
                    const ColorScheme.dark(primary: kOrange, surface: kCard),
                dialogTheme: const DialogThemeData(backgroundColor: kCard)),
            child: child!));

// pill con la fecha elegida + icono de calendario, para registro y perfil
Widget pillFechaNacimiento(DateTime? fecha, VoidCallback onTap) {
  return GestureDetector(
      onTap: onTap,
      child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
              color: kBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kGrayDark)),
          child: Row(children: [
            Flexible(
                child: Text(fechaNacAMostrar(fecha),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 14))),
            const SizedBox(width: 8),
            const Icon(Icons.calendar_today_outlined, color: kGray, size: 14),
          ])));
}

// Condiciones de pie disponibles, reutilizadas entre registro y perfil.
List<Map<String, String>> get _condicionesPie => [
  {'value': 'none', 'label': tr('condition_none')},
  {'value': 'plantar-fasciitis', 'label': tr('condition_plantar_fasciitis')},
  {'value': 'bunions', 'label': tr('condition_bunions')},
  {'value': 'arthritis', 'label': tr('condition_arthritis')},
  {'value': 'other', 'label': tr('condition_other')},
];

// si no coincide con ninguna opción conocida (dato antiguo), se muestra tal cual
String etiquetaCondicion(String valor) {
  for (final c in _condicionesPie) {
    if (c['value'] == valor) {
      return c['label']!;
    }
  }
  return valor.isEmpty ? tr('condition_none') : valor;
}

// pills seleccionables a ancho completo, reutilizado entre registro y perfil
Widget selectorCondicionPie(
    String seleccionado, void Function(String) onChanged) {
  return Column(
      children: _condicionesPie
          .map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () => onChanged(c['value']!),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: seleccionado == c['value'] ? kGradient : null,
                      color: seleccionado == c['value'] ? null : kCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: seleccionado == c['value']
                              ? Colors.transparent
                              : kGrayDark),
                    ),
                    child: Text(c['label']!,
                        style: TextStyle(
                            color: seleccionado == c['value']
                                ? Colors.white
                                : kGray,
                            fontWeight: FontWeight.w500,
                            fontSize: 15)),
                  ),
                ),
              ))
          .toList());
}

// usa el id (DateTime completo) en vez de 'fecha', que solo tiene día/mes
String _formatFechaSesion(SesionActividad s,
    {String? separador, bool incluirHora = true}) {
  final fecha = DateTime.tryParse(s.id);
  if (fecha == null) {
    return incluirHora ? '${s.fecha} ${separador ?? tr('at_word')} ${s.hora}' : s.fecha;
  }
  final fechaLarga = '${fecha.day} ${tr('month_${fecha.month}')} ${fecha.year}';
  if (!incluirHora) {
    return fechaLarga;
  }
  final hora = '${fecha.hour}:${fecha.minute.toString().padLeft(2, '0')}';
  return '$fechaLarga ${separador ?? tr('at_word')} $hora';
}

// Validaciones reutilizables de formularios (email y contraseña).
class Validadores {
  static bool esEmailValido(String email) =>
      RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
          .hasMatch(email);
  // mínimo 6 caracteres, una mayúscula y un número
  static bool esContraseniaValida(String pass) =>
      pass.length >= 6 &&
      pass.contains(RegExp(r'[A-Z]')) &&
      pass.contains(RegExp(r'[0-9]'));
}

// Estado global de la app (sesión y conexión BLE), sin gestores de estado externos
Usuario? usuarioActual; // usuario que ha iniciado sesión (null si no hay login)
List<SesionActividad> historial = []; // sesiones de actividad guardadas
// compartido con Quick Metrics del Home para que ambas vistas queden sincronizadas
String periodoMetricasSeleccionado = 'week';
// una instancia por pie (bleDer/bleIzq) para que las dos placas vayan sin pisarse
class FootBleState {
  BluetoothDevice? device;
  BluetoothCharacteristic? characteristic; // característica de datos de presión
  StreamSubscription<BluetoothConnectionState>? connSub;
  Timer? watchdog;

  void limpiar() {
    watchdog?.cancel();
    watchdog = null;
    device = null;
    characteristic = null;
  }
}

final FootBleState bleDer = FootBleState();
final FootBleState bleIzq = FootBleState();
FootBleState bleEstado(Pie pie) => pie == Pie.derecha ? bleDer : bleIzq;

StreamSubscription<BluetoothAdapterState>? _bleAdapterSubGlobal;

// ADC crudo (12 bits) a % usando 2 puntos por persona/plantilla; null = sin calibrar, valores de fábrica
class CalibracionPie {
  double? adcReposo; // ADC sin presión (0%)
  double? adcCarga; // ADC con todo el peso apoyado (100%)
  // referencia talón/punta para el reparto talón/metatarso (ver _pesoTalon): un solo sensor no distingue ambas zonas
  double? adcTalon;
  double? adcPunta;
}

final CalibracionPie calibDer = CalibracionPie();
final CalibracionPie calibIzq = CalibracionPie();
CalibracionPie calibPie(Pie pie) => pie == Pie.derecha ? calibDer : calibIzq;
const double _kAdcReposoFabrica = 1800;
const double _kAdcCargaFabrica = 1100;

String _sufijoPie(Pie pie) => pie == Pie.derecha ? 'der' : 'izq';

// separada por cuenta (ver _claveUsuario): cada cuenta tiene su propia calibración
Future<void> cargarCalibracion(Pie pie) async {
  final prefs = await SharedPreferences.getInstance();
  final c = calibPie(pie);
  final s = _sufijoPie(pie);
  c.adcReposo = prefs.getDouble(_claveUsuario('calibAdcReposo_$s'));
  c.adcCarga = prefs.getDouble(_claveUsuario('calibAdcCarga_$s'));
  c.adcTalon = prefs.getDouble(_claveUsuario('calibAdcTalon_$s'));
  c.adcPunta = prefs.getDouble(_claveUsuario('calibAdcPunta_$s'));
}

// deja la calibración activa en memoria, separada por cuenta
Future<void> guardarCalibracion(
    Pie pie, double adcReposo, double adcCarga, double adcTalon, double adcPunta) async {
  final c = calibPie(pie);
  c.adcReposo = adcReposo;
  c.adcCarga = adcCarga;
  c.adcTalon = adcTalon;
  c.adcPunta = adcPunta;
  final prefs = await SharedPreferences.getInstance();
  final s = _sufijoPie(pie);
  await prefs.setDouble(_claveUsuario('calibAdcReposo_$s'), adcReposo);
  await prefs.setDouble(_claveUsuario('calibAdcCarga_$s'), adcCarga);
  await prefs.setDouble(_claveUsuario('calibAdcTalon_$s'), adcTalon);
  await prefs.setDouble(_claveUsuario('calibAdcPunta_$s'), adcPunta);
}

// sin tope superior a propósito: una pisada real puede superar el pico calibrado
double adcAPresion(double adc, Pie pie) {
  final c = calibPie(pie);
  final reposo = c.adcReposo ?? _kAdcReposoFabrica;
  final carga = c.adcCarga ?? _kAdcCargaFabrica;
  final rango = reposo - carga;
  if (rango <= 0) {
    return 0;
  }
  final presion = 100 * (reposo - adc) / rango;
  return presion < 0 ? 0 : presion;
}

// vigila la conexión BLE durante toda la vida de la app, no solo con la pantalla montada
void iniciarMonitorBle(BluetoothDevice device, Pie pie) {
  final estado = bleEstado(pie);
  estado.device = device;
  estado.connSub?.cancel();
  estado.connSub = device.connectionState.listen((s) {
    if (s == BluetoothConnectionState.disconnected) {
      estado.limpiar();
    }
  });
  _bleAdapterSubGlobal ??= FlutterBluePlus.adapterState.listen((s) {
    if (s != BluetoothAdapterState.on) {
      bleDer.limpiar();
      bleIzq.limpiar();
    }
  });

  // ping leyendo RSSI cada pocos segundos en vez de esperar el supervision timeout del SO (hasta 20s)
  estado.watchdog?.cancel();
  estado.watchdog =
      Timer.periodic(const Duration(seconds: 3), (timer) async {
    if (estado.device != device) {
      timer.cancel();
      return;
    }
    try {
      await device.readRssi(timeout: 2);
    } catch (_) {
      timer.cancel();
      if (estado.device == device) {
        estado.limpiar();
      }
    }
  });
}

// escanea por nombre o UUID de servicio, conecta y se suscribe a notificaciones
Future<bool> escanearYConectarPie(Pie pie,
    {Duration timeout = const Duration(seconds: 10)}) async {
  final id = idBlePara(pie);
  final completer = Completer<bool>();
  StreamSubscription<List<ScanResult>>? scanSub;
  Timer? timeoutTimer;

  Future<void> pararEscaneo() async {
    timeoutTimer?.cancel();
    await scanSub?.cancel();
    scanSub = null;
    if (FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.stopScan();
    }
  }

  timeoutTimer = Timer(timeout, () async {
    await pararEscaneo();
    if (!completer.isCompleted) {
      completer.complete(false);
    }
  });

  scanSub = FlutterBluePlus.scanResults.listen((results) async {
    for (final r in results) {
      final matchNombre = r.device.platformName == id.nombre;
      final matchUUID = r.advertisementData.serviceUuids.any((u) => u
          .toString()
          .toLowerCase()
          .contains(id.servicioUuid.toLowerCase()));
      if (matchNombre || matchUUID) {
        await pararEscaneo();
        if (completer.isCompleted) {
          return;
        }
        completer.complete(await _conectarYSuscribirPie(r.device, pie));
        return;
      }
    }
  });
  await FlutterBluePlus.startScan(timeout: timeout);
  return completer.future;
}

// reutiliza una conexión que ya estuviera activa (p.ej. desde otra pantalla)
Future<bool> _conectarYSuscribirPie(BluetoothDevice device, Pie pie) async {
  final id = idBlePara(pie);
  try {
    if (bleEstado(pie).device != device) {
      await device.connect(autoConnect: false).timeout(const Duration(seconds: 8));
    }
  } catch (_) {
    return false;
  }
  iniciarMonitorBle(device, pie);
  // sin esto Android negocia un intervalo conservador, muy por debajo de los ~100Hz reales; no existe en iOS/desktop
  try {
    await device.requestConnectionPriority(
        connectionPriorityRequest: ConnectionPriority.high);
  } catch (_) {}
  final services = await device.discoverServices();
  for (final s in services) {
    if (s.uuid.toString().toLowerCase() == id.servicioUuid) {
      for (final c in s.characteristics) {
        if (c.uuid.toString().toLowerCase() == id.caracteristicaUuid) {
          await c.setNotifyValue(true);
          bleEstado(pie).characteristic = c;
          return true;
        }
      }
    }
  }
  return false;
}

// lee FirebaseAuth directo: hace falta antes de que exista 'usuarioActual'
String _claveUsuario(String clave) {
  final email = FirebaseAuth.instance.currentUser?.email ?? '';
  return email.isEmpty ? clave : '${clave}_$email';
}

// separado por cuenta, ver _claveUsuario
Future<void> guardarHistorial() async {
  final prefs = await SharedPreferences.getInstance();
  final lista = historial
      .map((s) => jsonEncode({
            'id': s.id,
            'titulo': s.titulo,
            'descripcion': s.descripcion,
            'tipo': s.tipo,
            'fecha': s.fecha,
            'hora': s.hora,
            'duracion': s.duracion,
            'presionMeta': s.presionMeta,
            'presionTalon': s.presionTalon,
            'presionMetaIzq': s.presionMetaIzq,
            'presionTalonIzq': s.presionTalonIzq,
            'pasos': s.pasos,
            'cadencia': s.cadencia,
            'distanciaKm': s.distanciaKm,
            'balance': s.balance,
            'impacto': s.impacto,
            'impactoIzq': s.impactoIzq,
            'impactoKg': s.impactoKg,
            'zancadaRatio': s.zancadaRatio,
            'strikeIndexDer': s.strikeIndexDer,
            'strikeIndexIzq': s.strikeIndexIzq,
            'tieneBalance': s.tieneBalance,
            'tieneFatiga': s.tieneFatiga,
            'tieneStrikeDer': s.tieneStrikeDer,
            'tieneStrikeIzq': s.tieneStrikeIzq,
            'tieneImpacto': s.tieneImpacto,
            'fatiga': s.fatiga,
            'tramosFatiga': s.tramosFatiga,
            'datosSesion': s.datosSesion,
            'recorrido': s.recorrido,
            'adcReposoDer': s.adcReposoDer,
            'adcCargaDer': s.adcCargaDer,
            'adcTalonDer': s.adcTalonDer,
            'adcPuntaDer': s.adcPuntaDer,
            'adcReposoIzq': s.adcReposoIzq,
            'adcCargaIzq': s.adcCargaIzq,
            'adcTalonIzq': s.adcTalonIzq,
            'adcPuntaIzq': s.adcPuntaIzq,
          }))
      .toList();
  await prefs.setStringList(_claveUsuario('historial'), lista);
}

// reconstruye el historial en memoria, ordenado por id (fecha de creación)
Future<void> cargarHistorial() async {
  final prefs = await SharedPreferences.getInstance();
  final lista = prefs.getStringList(_claveUsuario('historial')) ?? [];
  historial = lista.map((s) {
    final m = jsonDecode(s);
    final datosSesion = (m['datosSesion'] as List<dynamic>?)
            ?.map((d) => Map<String, dynamic>.from(d))
            .toList() ??
        [];
    final recorrido = (m['recorrido'] as List<dynamic>?)
            ?.map((d) => Map<String, dynamic>.from(d))
            .toList() ??
        [];
    return SesionActividad(
      id: m['id'],
      titulo: m['titulo'],
      descripcion: m['descripcion'],
      tipo: m['tipo'],
      fecha: m['fecha'],
      hora: m['hora'],
      duracion: m['duracion'],
      presionMeta: (m['presionMeta'] as num).toDouble(),
      presionTalon: (m['presionTalon'] as num).toDouble(),
      // sesiones antiguas (antes de la segunda placa) no tienen estas claves
      presionMetaIzq: (m['presionMetaIzq'] as num?)?.toDouble() ?? 0,
      presionTalonIzq: (m['presionTalonIzq'] as num?)?.toDouble() ?? 0,
      pasos: (m['pasos'] as num?)?.toInt() ?? 0,
      cadencia: (m['cadencia'] as num?)?.toDouble() ?? 0,
      distanciaKm: (m['distanciaKm'] as num?)?.toDouble() ?? 0,
      balance: (m['balance'] as num?)?.toDouble() ?? 0,
      impacto: (m['impacto'] as num?)?.toDouble() ?? 0,
      impactoIzq: (m['impactoIzq'] as num?)?.toDouble() ?? 0,
      impactoKg: (m['impactoKg'] as num?)?.toDouble() ?? 0,
      zancadaRatio: (m['zancadaRatio'] as num?)?.toDouble() ?? 0,
      strikeIndexDer: (m['strikeIndexDer'] as num?)?.toDouble() ?? 0,
      strikeIndexIzq: (m['strikeIndexIzq'] as num?)?.toDouble() ?? 0,
      // sesiones antiguas sin estas claves se recalculan desde datosSesion
      tieneBalance: (m['tieneBalance'] as bool?) ??
          tieneDatosPieIzquierdo(datosSesion),
      tieneFatiga:
          (m['tieneFatiga'] as bool?) ?? tieneDatosFatiga(datosSesion),
      tieneStrikeDer: (m['tieneStrikeDer'] as bool?) ??
          tieneDatosStrikeIndex(datosSesion, Pie.derecha),
      tieneStrikeIzq: (m['tieneStrikeIzq'] as bool?) ??
          tieneDatosStrikeIndex(datosSesion, Pie.izquierda),
      tieneImpacto: (m['tieneImpacto'] as bool?) ?? datosSesion.isNotEmpty,
      fatiga: (m['fatiga'] as num?)?.toDouble() ?? calcularFatiga(datosSesion),
      tramosFatiga: (m['tramosFatiga'] as List<dynamic>?)
              ?.map((v) => (v as num).toDouble())
              .toList() ??
          tramosFatiga(datosSesion),
      datosSesion: datosSesion,
      recorrido: recorrido,
      adcReposoDer: (m['adcReposoDer'] as num?)?.toDouble(),
      adcCargaDer: (m['adcCargaDer'] as num?)?.toDouble(),
      adcTalonDer: (m['adcTalonDer'] as num?)?.toDouble(),
      adcPuntaDer: (m['adcPuntaDer'] as num?)?.toDouble(),
      adcReposoIzq: (m['adcReposoIzq'] as num?)?.toDouble(),
      adcCargaIzq: (m['adcCargaIzq'] as num?)?.toDouble(),
      adcTalonIzq: (m['adcTalonIzq'] as num?)?.toDouble(),
      adcPuntaIzq: (m['adcPuntaIzq'] as num?)?.toDouble(),
    );
  }).toList();
  historial.sort((a, b) => a.id.compareTo(b.id));
  // defensa contra duplicados exactos (mismo id) colados en lo ya guardado
  final idsVistos = <String>{};
  historial.retainWhere((s) => idsVistos.add(s.id));
  await purgarDatosCrudosAntiguos();
}

// tras esto se descartan las muestras crudas, solo hacen falta para el CSV de detalle
const Duration _kVidaDatosCrudos = Duration(hours: 24);

Future<void> purgarDatosCrudosAntiguos() async {
  final ahora = DateTime.now();
  var huboCambios = false;
  for (final s in historial) {
    if (s.datosSesion.isEmpty) {
      continue;
    }
    final fecha = DateTime.tryParse(s.id);
    if (fecha != null && ahora.difference(fecha) > _kVidaDatosCrudos) {
      s.datosSesion = [];
      huboCambios = true;
    }
  }
  if (huboCambios) {
    await guardarHistorial();
  }
}

// sesiones con id no parseable (no debería pasar) se incluyen siempre, para no perder datos
List<SesionActividad> sesionesEnPeriodo(String periodo) {
  final ahora = DateTime.now();
  final limite = switch (periodo) {
    'week' => ahora.subtract(const Duration(days: 7)),
    'month' => ahora.subtract(const Duration(days: 30)),
    'year' => ahora.subtract(const Duration(days: 365)),
    _ => null, // 'all'
  };
  final sesiones = historial.where((s) {
    final fecha = DateTime.tryParse(s.id);
    return fecha == null || limite == null || fecha.isAfter(limite);
  }).toList();
  sesiones.sort((a, b) => a.id.compareTo(b.id));
  return sesiones;
}

// cadencia media (spm) del periodo; 0 si no hay sesiones
double cadenciaMediaPeriodo(String periodo) {
  final sesiones = sesionesEnPeriodo(periodo);
  if (sesiones.isEmpty) {
    return 0;
  }
  return sesiones.map((s) => s.cadencia).reduce((a, b) => a + b) /
      sesiones.length;
}

// desequilibrio medio (0-100) de sesiones con dato real (ver tieneBalance); null si ninguna lo tiene
double? balanceMedioPeriodo(String periodo) {
  final sesiones =
      sesionesEnPeriodo(periodo).where((s) => s.tieneBalance).toList();
  if (sesiones.isEmpty) {
    return null;
  }
  final balanceMedio =
      sesiones.map((s) => s.balance).reduce((a, b) => a + b) /
          sesiones.length;
  return (balanceMedio - 50).abs() * 2;
}

// impacto medio (media de ambos pies) de sesiones con muestras crudas; null si ninguna las tiene
double? impactoMedioPeriodo(String periodo) {
  final sesiones =
      sesionesEnPeriodo(periodo).where((s) => s.tieneImpacto).toList();
  if (sesiones.isEmpty) {
    return null;
  }
  return sesiones
          .map((s) => (s.impacto + s.impactoIzq) / 2)
          .reduce((a, b) => a + b) /
      sesiones.length;
}

// desequilibrio: <15 normal, >35 marcado
Color colorDesequilibrio(double pct) {
  if (pct < 15) {
    return kTeal;
  }
  if (pct < 35) {
    return kOrange;
  }
  return kRed;
}

// por encima de 100 el pico medio ya supera la referencia de calibración
Color colorImpacto(double pct) {
  if (pct < 60) {
    return kTeal;
  }
  if (pct < 100) {
    return kOrange;
  }
  return kRed;
}

// ---- MAIN ----
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // sin este await, _claveUsuario() podía leer sin email y sobrescribir el historial con uno vacío
  await FirebaseAuth.instance.authStateChanges().first;
  await cargarHistorial();
  await cargarCalibracion(Pie.derecha);
  await cargarCalibracion(Pie.izquierda);
  await cargarIdiomaGuardado();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  final prefs = await SharedPreferences.getInstance();
  final firebaseUser = FirebaseAuth.instance.currentUser;
  if (firebaseUser != null) {
    usuarioActual = Usuario(
      email: firebaseUser.email ?? '',
      nombre: prefs.getString(_claveUsuario('nombre')) ?? '',
      apellido: prefs.getString(_claveUsuario('apellido')) ?? '',
      genero: prefs.getString(_claveUsuario('genero')) ?? 'Male',
      contrasena: '',
      altura: prefs.getDouble(_claveUsuario('altura')) ?? 0.0,
      peso: prefs.getDouble(_claveUsuario('peso')) ?? 0.0,
      cumpleanos: prefs.getString(_claveUsuario('cumpleanos')) ?? '',
      shoeSize: prefs.getDouble(_claveUsuario('shoeSize')) ?? 0.0,
      arco: prefs.getString(_claveUsuario('arco')) ?? 'Normal',
      fotoPath: prefs.getString(_claveUsuario('fotoPath')),
      patologia: prefs.getString(_claveUsuario('patologia')),
    );
  }
  runApp(const GogaitApp());
}

class GogaitApp extends StatelessWidget {
  const GogaitApp({super.key});
  @override
  Widget build(BuildContext context) {
    // envuelve toda la MaterialApp: al cambiar appLang.value reconstruye cualquier pantalla que use tr()
    return ValueListenableBuilder<AppLang>(
        valueListenable: appLang,
        builder: (_, __, ___) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              scaffoldBackgroundColor: kBg,
              fontFamily: 'SF Pro Display',
              colorScheme: const ColorScheme.dark(
                primary: kOrange,
                surface: kCard,
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: kBg,
                elevation: 0,
                iconTheme: IconThemeData(color: Colors.white),
                titleTextStyle: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600),
              ),
            ),
            home: const VistaSplash(),
          );
        });
  }
}

// ---- WIDGETS COMUNES ----
// botón con degradado naranja/rojo, o solo borde (outlined) para acciones secundarias
class GogaitButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  final bool outlined;
  final double? width;
  const GogaitButton(
      {super.key,
      required this.text,
      required this.onTap,
      this.outlined = false,
      this.width});

  @override
  State<GogaitButton> createState() => _GogaitButtonState();
}

class _GogaitButtonState extends State<GogaitButton> {
  bool _presionado = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _presionado = true),
      onTapUp: (_) => setState(() => _presionado = false),
      onTapCancel: () => setState(() => _presionado = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _presionado ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          width: widget.width ?? double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: widget.outlined ? null : kGradientFull,
            border: widget.outlined
                ? Border.all(color: kOrange.withValues(alpha: 0.4))
                : null,
            color: widget.outlined ? kCard : null,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Text(widget.text,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  letterSpacing: 0.5)),
        ),
      ),
    );
  }
}

// tarjeta base de casi todas las secciones de la app, opcionalmente pulsable
class GogaitCard extends StatefulWidget {
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  const GogaitCard({super.key, required this.child, this.padding, this.onTap});

  @override
  State<GogaitCard> createState() => _GogaitCardState();
}

class _GogaitCardState extends State<GogaitCard> {
  bool _presionado = false;

  @override
  Widget build(BuildContext context) {
    // solo se encoge si tiene onTap, si no no debe parecer interactiva
    final interactiva = widget.onTap != null;
    return GestureDetector(
      onTapDown: interactiva ? (_) => setState(() => _presionado = true) : null,
      onTapUp: interactiva ? (_) => setState(() => _presionado = false) : null,
      onTapCancel: interactiva ? () => setState(() => _presionado = false) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _presionado ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          width: double.infinity,
          padding: widget.padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kGrayDark.withValues(alpha: 0.5)),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

// Campo de texto con etiqueta, usado en formularios (login, registro, perfil).
class GogaitInput extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final int maxLines;
  const GogaitInput(
      {super.key,
      required this.label,
      required this.controller,
      this.hint,
      this.obscure = false,
      this.suffix,
      this.keyboardType,
      this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // label vacío: la pantalla ya pone su propio título encima
      if (label.isNotEmpty) ...[
        Text(label,
            style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 14)),
        const SizedBox(height: 8),
      ],
      TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[600]),
          filled: true,
          fillColor: kCard,
          suffixIcon: suffix,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF374151))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF374151))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: kOrange)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    ]);
  }
}

// Tarjetita pequeña para mostrar una métrica suelta (icono + valor + etiqueta).
class MetricChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const MetricChip(
      {super.key,
      required this.label,
      required this.value,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGrayDark.withValues(alpha: 0.5)),
      ),
      child: Stack(children: [
        Positioned(
            top: -4,
            right: -4,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: color.withValues(alpha: 0.2)),
            )),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: kGray, size: 18),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: kGray, fontSize: 11)),
        ]),
      ]),
    );
  }
}

// explica qué significa una métrica (Balance, Impact...) en una hoja simple
void mostrarInfoMetrica(BuildContext context, String titulo, String texto) {
  // showGeneralDialog en vez de showDialog: permite que la explicación "crezca" desde el icono que la abrió
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: titulo,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (ctx, animation, secondaryAnimation) => AlertDialog(
      backgroundColor: kCard,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: kGrayDark)),
      title: Text(titulo,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600)),
      content: Text(texto,
          style: const TextStyle(color: kGray, fontSize: 14, height: 1.4)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('got_it_button'), style: const TextStyle(color: kOrange))),
      ],
    ),
    transitionBuilder: (ctx, animation, secondaryAnimation, child) {
      final crece = CurvedAnimation(
          parent: animation, curve: Curves.easeOutBack, reverseCurve: Curves.easeInCubic);
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: ScaleTransition(scale: crece, child: child),
      );
    },
  );
}

// icono ⓘ que abre mostrarInfoMetrica al tocarlo
class InfoTip extends StatelessWidget {
  final String titulo;
  final String texto;
  const InfoTip({super.key, required this.titulo, required this.texto});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: () => mostrarInfoMetrica(context, titulo, texto),
      child: const Padding(
          padding: EdgeInsets.only(left: 4),
          child: Icon(Icons.info_outline, color: kGray, size: 14)));
}

// ---- SPLASH SCREEN ----
// logo animado; tras 3s pasa a Home si hay sesión, si no a la bienvenida
class VistaSplash extends StatefulWidget {
  const VistaSplash({super.key});
  @override
  State<VistaSplash> createState() => _VistaSplashState();
}

class _VistaSplashState extends State<VistaSplash>
    with TickerProviderStateMixin {
  late AnimationController _scaleCtrl, _fadeCtrl, _pulseCtrl;
  late Animation<double> _scaleAnim, _fadeAnim, _pulseAnim;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _pulseCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);

    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0)
        .animate(CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeOut));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(_fadeCtrl);
    _pulseAnim = Tween<double>(begin: 0.5, end: 1.0).animate(_pulseCtrl);

    _scaleCtrl.forward();
    Future.delayed(
        const Duration(milliseconds: 300), () => _fadeCtrl.forward());
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) {
        return;
      }
      final firebaseUser = FirebaseAuth.instance.currentUser;
      // perfil incompleto: VistaHome avisa con un diálogo, no hay pantalla intermedia
      final destino = firebaseUser == null
          ? const VistaBienvenida()
          : const VistaHome();
      Navigator.pushReplacement(
          context, gogaitRoute(builder: (_) => destino));
    });
    appLang.addListener(_onLangChange);
  }

  void _onLangChange() => setState(() {});

  @override
  void dispose() {
    appLang.removeListener(_onLangChange);
    _scaleCtrl.dispose();
    _fadeCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(children: [
        CustomPaint(painter: _GridPainter(), size: Size.infinite),
        Center(
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          ScaleTransition(
              scale: _scaleAnim,
              child: AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, child) => Container(
                  width: 128,
                  height: 128,
                  decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
                    BoxShadow(
                        color:
                            kOrange.withValues(alpha: 0.3 * _pulseAnim.value),
                        blurRadius: 60,
                        spreadRadius: 20)
                  ]),
                  child: child,
                ),
                child: Image.asset('assets/logo.png',
                    width: 128,
                    height: 128,
                    errorBuilder: (_, __, ___) => Container(
                          width: 128,
                          height: 128,
                          decoration: BoxDecoration(
                              gradient: kGradientFull, shape: BoxShape.circle),
                          child: const Icon(Icons.directions_walk,
                              color: Colors.white, size: 64),
                        )),
              )),
          const SizedBox(height: 24),
          FadeTransition(
              opacity: _fadeAnim,
              child: ShaderMask(
                shaderCallback: (bounds) => kGradientFull.createShader(bounds),
                child: const Text('GOGAIT',
                    style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 4)),
              )),
          const SizedBox(height: 48),
          FadeTransition(opacity: _fadeAnim, child: _DotsLoader()),
          const SizedBox(height: 16),
          FadeTransition(
              opacity: _fadeAnim,
              child: AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, __) => Opacity(
                      opacity: 0.5 + 0.5 * _pulseAnim.value,
                      child: Text(tr('splash_analyzing'),
                          style: const TextStyle(
                              color: kGray, fontSize: 14, letterSpacing: 1))))),
          const SizedBox(height: 8),
          FadeTransition(
              opacity: _fadeAnim,
              child: Text(tr('splash_connecting'),
                  style:
                      const TextStyle(color: Color(0xFF4B5563), fontSize: 12))),
        ])),
      ]),
    );
  }
}

// los 3 puntitos animados del splash, cada uno con su propio ritmo
class _DotsLoader extends StatefulWidget {
  @override
  State<_DotsLoader> createState() => _DotsLoaderState();
}

class _DotsLoaderState extends State<_DotsLoader>
    with TickerProviderStateMixin {
  late List<AnimationController> _ctrls;
  late List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(
        3,
        (i) => AnimationController(
            vsync: this, duration: const Duration(milliseconds: 1200))
          ..repeat(
              reverse: true, period: Duration(milliseconds: 1200 + i * 200)));
    _anims = _ctrls
        .map((c) => Tween<double>(begin: 0.5, end: 1.0).animate(c))
        .toList();
    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) {
          _ctrls[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (var c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
            3,
            (i) => AnimatedBuilder(
                animation: _anims[i],
                builder: (_, __) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [
                          kOrange.withValues(alpha: _anims[i].value),
                          kRed.withValues(alpha: _anims[i].value)
                        ]),
                      ),
                    ))));
  }
}

// Dibuja la rejilla de fondo sutil del splash.
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = kOrange.withValues(alpha: 0.04)
      ..strokeWidth = 1;
    const step = 50.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ---- WELCOME SCREEN ----
// Pantalla de bienvenida con los botones de Login / Register.
class VistaBienvenida extends StatefulWidget {
  const VistaBienvenida({super.key});
  @override
  State<VistaBienvenida> createState() => _VistaBienvenidaState();
}

class _VistaBienvenidaState extends State<VistaBienvenida>
    with TickerProviderStateMixin {
  late AnimationController _logoCtrl, _titleCtrl, _btnCtrl, _meshCtrl;
  late Animation<double> _logoScale,
      _logoOpacity,
      _titleSlide,
      _titleOpacity,
      _btnSlide,
      _btnOpacity;

  // Anima en cascada: primero el logo, luego el título, luego los botones.
  @override
  void initState() {
    super.initState();
    _logoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _titleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _btnCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    // mesh de fondo "respira" en bucle; ciclo largo (7s) para que no maree
    _meshCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 7))
      ..repeat(reverse: true);

    _logoScale = Tween<double>(begin: 0.9, end: 1.0)
        .animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut));
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(_logoCtrl);
    _titleSlide = Tween<double>(begin: 20, end: 0)
        .animate(CurvedAnimation(parent: _titleCtrl, curve: Curves.easeOut));
    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(_titleCtrl);
    _btnSlide = Tween<double>(begin: 20, end: 0)
        .animate(CurvedAnimation(parent: _btnCtrl, curve: Curves.easeOut));
    _btnOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(_btnCtrl);

    _logoCtrl.forward();
    Future.delayed(
        const Duration(milliseconds: 200), () => _titleCtrl.forward());
    Future.delayed(const Duration(milliseconds: 400), () => _btnCtrl.forward());
    // sin este listener el texto queda congelado al cambiar de idioma
    appLang.addListener(_onLangChange);
  }

  void _onLangChange() => setState(() {});

  @override
  void dispose() {
    appLang.removeListener(_onLangChange);
    _logoCtrl.dispose();
    _titleCtrl.dispose();
    _btnCtrl.dispose();
    _meshCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Positioned.fill(child: Container(color: Colors.black)),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: MediaQuery.of(context).size.height * 0.55,
          child: Transform.translate(
            offset: Offset(0, MediaQuery.of(context).size.height * 0.05),
            child: AnimatedBuilder(
              animation: _meshCtrl,
              builder: (context, child) {
                // t: 0 en mitad del ciclo, 1 en extremos; comparte escala/giro y brillo
                final t = _meshCtrl.value;
                return Transform.scale(
                  scale: 1.0 + t * 0.06,
                  child: Transform.rotate(
                    angle: (t - 0.5) * 0.025,
                    child: Stack(fit: StackFit.expand, children: [
                      child!,
                      // brillo cálido que pulsa por encima del mesh
                      IgnorePointer(
                        child: Opacity(
                          opacity: 0.15 + t * 0.25,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: Alignment.bottomCenter,
                                radius: 1.0,
                                colors: [
                                  kOrange.withValues(alpha: 0.6),
                                  kRed.withValues(alpha: 0.25),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ]),
                  ),
                );
              },
              child: Image.asset('assets/mesh-bg.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment.bottomCenter,
                            radius: 1.2,
                            colors: [
                              kRed.withValues(alpha: 0.3),
                              kOrange.withValues(alpha: 0.15),
                              Colors.black
                            ],
                          ),
                        ),
                      )),
            ),
          ),
        ),
        Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.50))),
        SafeArea(
            child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 12, 20, 0),
                    child: _SelectorIdioma()))),
        SafeArea(
            child: Column(children: [
          const Spacer(),
          AnimatedBuilder(
              animation: _logoCtrl,
              builder: (_, child) => Opacity(
                    opacity: _logoOpacity.value,
                    child:
                        Transform.scale(scale: _logoScale.value, child: child),
                  ),
              child: Column(children: [
                Stack(alignment: Alignment.center, children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration:
                        BoxDecoration(shape: BoxShape.circle, boxShadow: [
                      BoxShadow(
                          color: kOrange.withValues(alpha: 0.4),
                          blurRadius: 40,
                          spreadRadius: 10)
                    ]),
                  ),
                  Image.asset('assets/logo.png',
                      width: 96,
                      height: 96,
                      errorBuilder: (_, __, ___) => Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                                gradient: kGradientFull,
                                shape: BoxShape.circle),
                            child: const Icon(Icons.directions_walk,
                                color: Colors.white, size: 48),
                          )),
                ]),
                const SizedBox(height: 24),
                AnimatedBuilder(
                    animation: _titleCtrl,
                    builder: (_, __) => Opacity(
                          opacity: _titleOpacity.value,
                          child: Transform.translate(
                            offset: Offset(0, _titleSlide.value),
                            child: Column(children: [
                              RichText(
                                  text: TextSpan(
                                style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1),
                                children: [
                                  const TextSpan(
                                      text: 'GOG',
                                      style: TextStyle(color: Colors.white)),
                                  WidgetSpan(
                                      child: ShaderMask(
                                    shaderCallback: (b) => const LinearGradient(
                                            colors: [kRed, kOrange])
                                        .createShader(b),
                                    child: const Text('A',
                                        style: TextStyle(
                                            fontSize: 36,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white)),
                                  )),
                                  const TextSpan(
                                      text: 'IT',
                                      style: TextStyle(color: Colors.white)),
                                ],
                              )),
                              const SizedBox(height: 8),
                              Text(tr('welcome_tagline'),
                                  style: const TextStyle(
                                      color: Color(0xFFD1D5DB), fontSize: 16)),
                            ]),
                          ),
                        )),
              ])),
          const Spacer(),
          AnimatedBuilder(
              animation: _btnCtrl,
              builder: (_, child) => Opacity(
                    opacity: _btnOpacity.value,
                    child: Transform.translate(
                        offset: Offset(0, _btnSlide.value), child: child),
                  ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Column(children: [
                  GogaitButton(
                      text: tr('login'),
                      onTap: () => Navigator.push(
                          context,
                          gogaitRoute(
                              builder: (_) => const VistaLogin()))),
                  const SizedBox(height: 12),
                  GogaitButton(
                      text: tr('register'),
                      outlined: true,
                      onTap: () => Navigator.push(
                          context,
                          gogaitRoute(
                              builder: (_) => const VistaRegistro()))),
                  const SizedBox(height: 16),
                  Text(tr('welcome_footer'),
                      style:
                          const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                ]),
              )),
        ])),
      ]),
    );
  }
}

// pastilla con la bandera actual; al tocarla abre la hoja con los 6 idiomas
class _SelectorIdioma extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLang>(
        valueListenable: appLang,
        builder: (context, idiomaActual, __) {
          return GestureDetector(
              onTap: () => _abrirSelectorIdioma(context),
              child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                      color: kCard.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(idiomaActual.flag,
                        style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    const Icon(Icons.keyboard_arrow_down,
                        color: Colors.white, size: 16),
                  ])));
        });
  }

  void _abrirSelectorIdioma(BuildContext context) {
    showModalBottomSheet(
        context: context,
        backgroundColor: kCard,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (ctx) => SafeArea(
                child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(tr('select_language'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                ...AppLang.values.map((lang) => ValueListenableBuilder<AppLang>(
                    valueListenable: appLang,
                    builder: (_, actual, __) => ListTile(
                        onTap: () {
                          cambiarIdioma(lang);
                          Navigator.pop(ctx);
                        },
                        leading: Text(lang.flag,
                            style: const TextStyle(fontSize: 22)),
                        title: Text(lang.nombreNativo,
                            style: const TextStyle(color: Colors.white)),
                        trailing: actual == lang
                            ? const Icon(Icons.check_circle,
                                color: kOrange, size: 20)
                            : null))),
              ]),
            )));
  }
}

// ---- LOGIN SCREEN ----
// Pantalla de inicio de sesión con email y contraseña (Firebase Auth).
class VistaLogin extends StatefulWidget {
  const VistaLogin({super.key});
  @override
  State<VistaLogin> createState() => _VistaLoginState();
}

class _VistaLoginState extends State<VistaLogin> with IdiomaListenerMixin {
  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  bool _showPass = false;

  void _snack(String msg, {bool isError = true}) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: kCard,
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
            color: isError
                ? kRed.withValues(alpha: 0.4)
                : kTeal.withValues(alpha: 0.4)),
      ),
      content: Row(children: [
        Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
            color: isError ? kRed : kTeal, size: 20),
        const SizedBox(width: 10),
        Expanded(
            child: Text(msg,
                style: const TextStyle(color: Colors.white, fontSize: 14))),
      ]),
    ));
  }

  void _login() async {
    if (!Validadores.esEmailValido(_emailC.text)) {
      _snack(tr('err_invalid_email'));
      return;
    }
    if (_passC.text.isEmpty) {
      _snack(tr('err_enter_password'));
      return;
    }
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailC.text.trim(),
        password: _passC.text.trim(),
      );
      final prefs = await SharedPreferences.getInstance();
      usuarioActual = Usuario(
        email: _emailC.text.trim(),
        nombre: prefs.getString(_claveUsuario('nombre')) ?? '',
        apellido: prefs.getString(_claveUsuario('apellido')) ?? '',
        genero: prefs.getString(_claveUsuario('genero')) ?? 'Male',
        contrasena: _passC.text,
        altura: prefs.getDouble(_claveUsuario('altura')) ?? 0.0,
        peso: prefs.getDouble(_claveUsuario('peso')) ?? 0.0,
        cumpleanos: prefs.getString(_claveUsuario('cumpleanos')) ?? '',
        shoeSize: prefs.getDouble(_claveUsuario('shoeSize')) ?? 0.0,
        arco: prefs.getString(_claveUsuario('arco')) ?? 'Normal',
        fotoPath: prefs.getString(_claveUsuario('fotoPath')),
        patologia: prefs.getString(_claveUsuario('patologia')),
      );
      if (!mounted) {
        return;
      }
      Navigator.pushAndRemoveUntil(context,
          gogaitRoute(builder: (_) => const VistaHome()), (_) => false);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        _snack(tr('err_user_not_found'));
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        _snack(tr('err_wrong_password'));
      } else if (e.code == 'invalid-email') {
        _snack(tr('err_invalid_email_format'));
      } else if (e.code == 'too-many-requests') {
        _snack(tr('err_too_many_attempts'));
      } else {
        _snack('${tr('err_login_generic')}: ${e.message}');
      }
    }
  }

  @override
  void dispose() {
    _emailC.dispose();
    _passC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(children: [
        SafeArea(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  const SizedBox(height: 40),
                  Stack(alignment: Alignment.center, children: [
                    Container(
                        width: 64,
                        height: 64,
                        decoration:
                            BoxDecoration(shape: BoxShape.circle, boxShadow: [
                          BoxShadow(
                              color: kOrange.withValues(alpha: 0.3),
                              blurRadius: 30,
                              spreadRadius: 10)
                        ])),
                    Image.asset('assets/logo.png',
                        width: 64,
                        height: 64,
                        errorBuilder: (_, __, ___) => Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                                gradient: kGradientFull,
                                shape: BoxShape.circle),
                            child: const Icon(Icons.directions_walk,
                                color: Colors.white, size: 32))),
                  ]),
                  const SizedBox(height: 16),
                  ShaderMask(
                    shaderCallback: (b) => kGradient.createShader(b),
                    child: Text(tr('login_welcome_back'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 6),
                  Text(tr('login_subtitle'),
                      style: const TextStyle(
                          color: Color(0xFF9CA3AF), fontSize: 14)),
                  const SizedBox(height: 36),
                  GogaitInput(
                      label: tr('email_label'),
                      hint: tr('email_hint'),
                      controller: _emailC,
                      keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 18),
                  GogaitInput(
                      label: tr('password_label'),
                      hint: tr('password_hint'),
                      controller: _passC,
                      obscure: !_showPass,
                      suffix: IconButton(
                          icon: Icon(
                              _showPass
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: const Color(0xFF6B7280),
                              size: 20),
                          onPressed: () =>
                              setState(() => _showPass = !_showPass))),
                  const SizedBox(height: 12),
                  Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                          onPressed: () async {
                            if (!Validadores.esEmailValido(_emailC.text)) {
                              _snack(tr('err_enter_email_first'));
                              return;
                            }
                            try {
                              await FirebaseAuth.instance
                                  .sendPasswordResetEmail(
                                email: _emailC.text.trim(),
                              );
                              _snack(tr('password_reset_sent'), isError: false);
                            } on FirebaseAuthException catch (e) {
                              _snack('${tr('error_prefix')}: ${e.message}');
                            }
                          },
                          child: Text(tr('forgot_password'),
                              style: const TextStyle(
                                  color: kOrange, fontSize: 14)))),

                  const SizedBox(height: 24),
                  GogaitButton(text: tr('login'), onTap: _login),
                  const SizedBox(height: 24),
                  Wrap(alignment: WrapAlignment.center, children: [
                    Text(tr('no_account'),
                        style: const TextStyle(color: kGray, fontSize: 14)),
                    GestureDetector(
                        onTap: () => Navigator.pushReplacement(
                            context,
                            gogaitRoute(
                                builder: (_) => const VistaRegistro())),
                        child: Text(tr('register_here'),
                            style: const TextStyle(
                                color: kOrange,
                                fontSize: 14,
                                fontWeight: FontWeight.w600))),
                  ]),
                ]))),
        SafeArea(
            child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                    padding: const EdgeInsets.only(right: 16, top: 8),
                    child: _SelectorIdioma()))),
      ]),
    );
  }
}

// ---- REGISTER SCREEN ----
// registro en 4 pasos: datos, medidas, pie, salud
class VistaRegistro extends StatefulWidget {
  const VistaRegistro({super.key});
  @override
  State<VistaRegistro> createState() => _VistaRegistroState();
}

class _VistaRegistroState extends State<VistaRegistro> with IdiomaListenerMixin {
  int _step = 1;
  final _nameC = TextEditingController(), _emailC = TextEditingController();
  final _apellidoC = TextEditingController();
  final _passC = TextEditingController();
  DateTime? _fechaNac;
  double _altura = 170, _peso = 70, _shoeSize = 42;
  String _genero = 'Male', _arco = 'Normal', _patologia = 'none';
  bool _showPass = false;

  void _snack(String msg, {bool isError = true}) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: kCard,
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
            color: isError
                ? kRed.withValues(alpha: 0.4)
                : kTeal.withValues(alpha: 0.4)),
      ),
      content: Row(children: [
        Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
            color: isError ? kRed : kTeal, size: 20),
        const SizedBox(width: 10),
        Expanded(
            child: Text(msg,
                style: const TextStyle(color: Colors.white, fontSize: 14))),
      ]),
    ));
  }

  void _next() async {
    if (_step == 1) {
      if (_nameC.text.trim().isEmpty) {
        _snack(tr('err_first_name'));
        return;
      }
      if (_apellidoC.text.trim().isEmpty) {
        _snack(tr('err_last_name'));
        return;
      }
      if (!Validadores.esEmailValido(_emailC.text)) {
        _snack(tr('err_valid_email'));
        return;
      }
      if (!Validadores.esContraseniaValida(_passC.text)) {
        _snack(tr('err_password_rules'));
        return;
      }
      if (_fechaNac == null) {
        _snack(tr('err_dob'));
        return;
      }
    }
    if (_step < 4) {
      setState(() => _step++);
      return;
    }

    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailC.text.trim(),
        password: _passC.text.trim(),
      );

      // la contraseña no se guarda aquí, Firebase Auth ya es la fuente de verdad
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_claveUsuario('nombre'), _nameC.text);
      await prefs.setString(_claveUsuario('apellido'), _apellidoC.text);
      await prefs.setDouble(_claveUsuario('altura'), _altura);
      await prefs.setDouble(_claveUsuario('peso'), _peso);
      await prefs.setString(
          _claveUsuario('cumpleanos'), fechaNacAGuardar(_fechaNac!));
      await prefs.setDouble(_claveUsuario('shoeSize'), _shoeSize);
      await prefs.setString(_claveUsuario('genero'), _genero);
      await prefs.setString(_claveUsuario('arco'), _arco);
      await prefs.setString(_claveUsuario('patologia'), _patologia);

      usuarioActual = Usuario(
        email: _emailC.text.trim(),
        nombre: _nameC.text,
        apellido: _apellidoC.text,
        genero: _genero,
        contrasena: _passC.text,
        altura: _altura,
        peso: _peso,
        cumpleanos: fechaNacAGuardar(_fechaNac!),
        shoeSize: _shoeSize,
        arco: _arco,
        patologia: _patologia == 'none' ? null : _patologia,
      );

      if (!mounted) {
        return;
      }
      Navigator.pushAndRemoveUntil(context,
          gogaitRoute(builder: (_) => const VistaHome()), (_) => false);
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException: ${e.code} - ${e.message}');
      if (e.code == 'email-already-in-use') {
        _snack(tr('err_email_in_use'));
      } else if (e.code == 'weak-password') {
        _snack(tr('err_weak_password'));
      } else if (e.code == 'invalid-email') {
        _snack(tr('err_invalid_email_format'));
      } else {
        _snack('${tr('err_registration_generic')}: ${e.message}');
      }
    } catch (e) {
      debugPrint('Error general: $e');
      _snack('${tr('error_prefix')}: $e');
    }
  }

  // Slider con etiqueta y unidad (usado para altura, peso y talla de zapato).
  Widget _buildSlider(String label, double value, double min, double max,
      String unit, void Function(double) onChanged) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$label: ${value.toInt()} $unit',
          style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 14)),
      const SizedBox(height: 8),
      SliderTheme(
        data: SliderTheme.of(context).copyWith(
          activeTrackColor: kGrayDark,
          inactiveTrackColor: kGrayDark,
          thumbColor: kOrange,
          overlayColor: kOrange.withValues(alpha: 0.15),
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
          trackHeight: 4,
        ),
        child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: (v) => setState(() => onChanged(v))),
      ),
    ]);
  }

  // Botón de selección simple (usado para elegir género).
  Widget _selectBtn(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: selected ? kGradient : null,
          color: selected ? null : kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? Colors.transparent : kGrayDark),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : kGray,
                fontWeight: FontWeight.w600,
                fontSize: 14)),
      ),
    );
  }

  // Botón de selección con símbolo encima (usado para el tipo de arco del pie).
  Widget _archBtn(
      String label, String symbol, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: selected ? kGradient : null,
          color: selected ? null : kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? Colors.transparent : kGrayDark),
        ),
        alignment: Alignment.center,
        child: Column(children: [
          Text(symbol,
              style: TextStyle(
                  color: selected ? Colors.white : kGray, fontSize: 22)),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  color: selected ? Colors.white : kGray,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
          child: Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(children: [
              GestureDetector(
                  onTap: _step == 1
                      ? () => Navigator.pop(context)
                      : () => setState(() => _step--),
                  child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          color: kCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kGrayDark)),
                      child: const Icon(Icons.chevron_left,
                          color: Colors.white, size: 20))),
              Expanded(
                  child: Text(tr('reg_create_account'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 18))),
              const SizedBox(width: 36),
            ])),
        Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Column(children: [
              Row(
                  children: List.generate(
                      4,
                      (i) => Expanded(
                              child: Container(
                            height: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              gradient: i < _step ? kGradient : null,
                              color: i < _step ? null : kGrayDark,
                            ),
                          )))),
              const SizedBox(height: 6),
              Text(tr('reg_step_of').replaceAll('{n}', '$_step'),
                  style: const TextStyle(color: kGray, fontSize: 12)),
            ])),
        Expanded(
            child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_step == 1) ...[
                        Text(tr('reg_personal_info'),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 24),
                        GogaitInput(
                            label: tr('first_name'),
                            hint: 'John',
                            controller: _nameC),
                        const SizedBox(height: 16),
                        GogaitInput(
                            label: tr('last_name'),
                            hint: 'Doe',
                            controller: _apellidoC),
                        const SizedBox(height: 16),
                        GogaitInput(
                            label: tr('email_label'),
                            hint: tr('email_hint'),
                            controller: _emailC,
                            keyboardType: TextInputType.emailAddress),
                        const SizedBox(height: 16),
                        GogaitInput(
                            label: tr('password_label'),
                            hint: tr('password_hint_rules'),
                            controller: _passC,
                            obscure: !_showPass,
                            suffix: IconButton(
                                icon: Icon(
                                    _showPass
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: kGray,
                                    size: 20),
                                onPressed: () =>
                                    setState(() => _showPass = !_showPass))),
                        const SizedBox(height: 16),
                        Text(tr('reg_date_of_birth'),
                            style: const TextStyle(
                                color: Color(0xFFD1D5DB), fontSize: 14)),
                        const SizedBox(height: 8),
                        pillFechaNacimiento(_fechaNac, () async {
                          final picked =
                              await elegirFechaNacimiento(context, _fechaNac);
                          if (picked != null) {
                            setState(() => _fechaNac = picked);
                          }
                        }),
                      ],
                      if (_step == 2) ...[
                        Text(tr('reg_physical_metrics'),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 28),
                        _buildSlider(tr('height'), _altura, 140, 220, 'cm',
                            (v) => _altura = v),
                        const SizedBox(height: 24),
                        _buildSlider(
                            tr('weight'), _peso, 40, 150, 'kg', (v) => _peso = v),
                        const SizedBox(height: 24),
                        _buildSlider(tr('shoe_size_eu'), _shoeSize, 35, 50, 'EU',
                            (v) => _shoeSize = v),
                        const SizedBox(height: 24),
                        Text(tr('gender'),
                            style: const TextStyle(
                                color: Color(0xFFD1D5DB), fontSize: 14)),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(
                              child: _selectBtn(tr('male'), _genero == 'Male',
                                  () => setState(() => _genero = 'Male'))),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _selectBtn(tr('female'), _genero == 'Female',
                                  () => setState(() => _genero = 'Female'))),
                        ]),
                      ],
                      if (_step == 3) ...[
                        Text(tr('reg_foot_biomechanics'),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 24),
                        Text(tr('foot_arch_type'),
                            style: const TextStyle(
                                color: Color(0xFFD1D5DB), fontSize: 14)),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(
                              child: _archBtn(tr('arch_flat'), '—', _arco == 'Flat',
                                  () => setState(() => _arco = 'Flat'))),
                          const SizedBox(width: 8),
                          Expanded(
                              child: _archBtn(tr('arch_normal'), '⌢', _arco == 'Normal',
                                  () => setState(() => _arco = 'Normal'))),
                          const SizedBox(width: 8),
                          Expanded(
                              child: _archBtn(tr('arch_high'), '⌒', _arco == 'High',
                                  () => setState(() => _arco = 'High'))),
                        ]),
                        const SizedBox(height: 20),
                        Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                                color: kCard,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: kGrayDark)),
                            child: Text(tr('reg_arch_info'),
                                style: const TextStyle(
                                    color: kGray, fontSize: 13, height: 1.5))),
                      ],
                      if (_step == 4) ...[
                        Text(tr('reg_health_info_title'),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Text(tr('reg_health_question'),
                            style: const TextStyle(color: kGray, fontSize: 14)),
                        const SizedBox(height: 20),
                        selectorCondicionPie(
                            _patologia, (v) => setState(() => _patologia = v)),
                        const SizedBox(height: 8),
                        Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                                color: kCard,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: kGrayDark)),
                            child: Text(tr('reg_health_info'),
                                style: const TextStyle(
                                    color: kGray, fontSize: 13, height: 1.5))),
                      ],
                    ]))),
        Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: Row(children: [
              if (_step > 1) ...[
                GestureDetector(
                    onTap: () => setState(() => _step--),
                    child: Container(
                        height: 56,
                        width: 90,
                        decoration: BoxDecoration(
                            color: kCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: kGrayDark)),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.chevron_left,
                                  color: Colors.white, size: 18),
                              const SizedBox(width: 4),
                              Text(tr('back'),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14)),
                            ]))),
                const SizedBox(width: 12),
              ],
              Expanded(
                  child: GestureDetector(
                onTap: _next,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                      gradient: kGradient,
                      borderRadius: BorderRadius.circular(16)),
                  alignment: Alignment.center,
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_step < 4 ? tr('next') : tr('reg_create_account'),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16)),
                        if (_step < 4) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.chevron_right,
                              color: Colors.white, size: 20)
                        ],
                      ]),
                ),
              )),
            ])),
      ])),
    );
  }
}

// ---- HOME SCREEN ----
class VistaHome extends StatefulWidget {
  const VistaHome({super.key});

  @override
  State<VistaHome> createState() => _VistaHomeState();
}

class _VistaHomeState extends State<VistaHome> with IdiomaListenerMixin {
  int get _bleConectados =>
      (bleDer.device != null ? 1 : 0) + (bleIzq.device != null ? 1 : 0);
  bool get _bleConectado => _bleConectados > 0;
  bool get _bleAmbosConectados => _bleConectados == 2;
  Timer? _bleCheckTimer;

  // N/A si ninguna sesión del periodo tiene el dato (ver periodoMetricasSeleccionado)
  List<Map<String, dynamic>> get metrics {
    final balance = balanceMedioPeriodo(periodoMetricasSeleccionado);
    final impacto = impactoMedioPeriodo(periodoMetricasSeleccionado);
    return [
      {
        // preview de Quick Metrics: colorea por umbral, el resto de la app usa color fijo
        'label': tr('metric_balance'),
        'value': balance == null ? 'N/A' : '${balance.round()}%',
        'color': balance == null ? kGray : colorDesequilibrio(balance),
        'icon': Icons.my_location,
        'info': tr('balance_info'),
      },
      {
        // siempre en %, igual que Quick Metrics; el kg es solo para una sesión suelta
        'label': tr('metric_impact'),
        'value': impacto == null ? 'N/A' : '${impacto.round()}%',
        'color': impacto == null ? kGray : colorImpacto(impacto),
        'icon': Icons.speed,
        'info': tr('impact_info'),
      },
      {
        'label': tr('metric_cadence'),
        'value': '${cadenciaMediaPeriodo(periodoMetricasSeleccionado).round()} spm',
        // mismo morado que Cadence en Activity Details
        'color': kPurple,
        'icon': Icons.trending_up,
        'info': tr('cadence_info'),
      },
    ];
  }

  @override
  void initState() {
    super.initState();
    // bleDer/bleIzq pueden cambiar en segundo plano (p.ej. se apaga el Bluetooth), refresco periódico
    _bleCheckTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
    if (_perfilIncompleto(usuarioActual)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _avisarPerfilIncompleto();
        }
      });
    }
  }

  void _avisarPerfilIncompleto() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: kGrayDark)),
        title: Text(tr('complete_profile_title'),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
        content: Text(tr('complete_profile_message'),
            style: const TextStyle(color: kGray, fontSize: 14, height: 1.4)),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(context,
                    gogaitRoute(builder: (_) => const VistaAjustes()));
              },
              child: Text(tr('complete_profile_button'),
                  style: const TextStyle(color: kOrange))),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _bleCheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Expanded + ellipsis: nombre largo no debe empujar el selector/avatar fuera de pantalla.
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('home_hello').replaceAll('{name}',
                              usuarioActual?.nombre ?? tr('user_fallback')),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tr('home_subtitle'),
                          style: const TextStyle(color: kGray, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Row(children: [
                    _SelectorIdioma(),
                    const SizedBox(width: 10),
                    GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                          context,
                          gogaitRoute(
                              builder: (_) => const VistaAjustes()));
                      setState(() {});
                    },
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                              gradient: kGradientFull, shape: BoxShape.circle),
                          child: usuarioActual?.fotoPath != null
                              ? ClipOval(
                                  child: Image.file(
                                      File(usuarioActual!.fotoPath!),
                                      fit: BoxFit.cover))
                              : const Icon(Icons.person,
                                  color: Colors.white, size: 24),
                        ),
                        // Insignia de ajustes: distingue este acceso de otros avatares que no llevan a ningún sitio.
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                                color: kCard,
                                shape: BoxShape.circle,
                                border: Border.all(color: kBg, width: 2)),
                            child: const Icon(Icons.settings,
                                color: kOrange, size: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ]),
                ],
              ),
              const SizedBox(height: 20),

              GogaitCard(
                onTap: () async {
                  await Navigator.push(
                      context,
                      gogaitRoute(
                          builder: (_) => const VistaBluetooth()));
                  setState(() {});
                },
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(children: [
                          Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _bleConectado
                                      ? kTeal.withValues(alpha: 0.15)
                                      : kGray.withValues(alpha: 0.15)),
                              child: Icon(Icons.bluetooth,
                                  color: _bleConectado ? kTeal : kGray,
                                  size: 18)),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      _bleAmbosConectados
                                          ? tr('insoles_connected')
                                          : _bleConectado
                                              ? tr('insoles_partial')
                                              : tr('insoles_disconnected'),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600)),
                                  Text(
                                      _bleConectado
                                          ? tr('insoles_count').replaceAll(
                                              '{n}', '$_bleConectados')
                                          : tr('tap_to_connect'),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      style: TextStyle(
                                          color:
                                              _bleConectado ? kTeal : kGray,
                                          fontSize: 11)),
                                ]),
                          ),
                        ]),
                      ),
                      Row(children: [
                        Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _bleConectado ? kTeal : kGray)),
                        const SizedBox(width: 6),
                        Text(_bleConectado ? tr('status_active') : tr('status_offline'),
                            style: TextStyle(
                                color: _bleConectado ? kTeal : kGray,
                                fontSize: 12)),
                      ]),
                    ]),
              ),
              const SizedBox(height: 16),

              GogaitCard(
                onTap: historial.isNotEmpty
                    ? () async {
                        await Navigator.push(
                            context,
                            gogaitRoute(
                                builder: (_) => VistaDetalleHistorico(
                                    sesion: historial.last)));
                        setState(() {});
                      }
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(tr('last_activity'),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            // Sin hora: con hora incluida el texto no cabía junto al título y siempre se recortaba.
                            historial.isNotEmpty
                                ? _formatFechaSesion(historial.last,
                                    incluirHora: false)
                                : '—',
                            textAlign: TextAlign.end,
                            style: const TextStyle(color: kGray, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: kOrange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: kOrange.withValues(alpha: 0.25)),
                          ),
                          child: const Icon(Icons.directions_run,
                              color: kOrange, size: 28),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                historial.isNotEmpty
                                    ? historial.last.titulo
                                    : '',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                historial.isNotEmpty
                                    ? historial.last.duracion
                                    : '',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: const TextStyle(
                                    color: kGray, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(tr('quick_metrics'),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16)),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                          context,
                          gogaitRoute(
                              builder: (_) => const VistaExportMetrics()));
                      setState(() {});
                    },
                    child: Text(tr('export_your_data'),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: const TextStyle(color: kTeal, fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Builder(builder: (context) {
                final metricsList = metrics;
                return Row(
                  children: metricsList
                      .map((m) => Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                  right: m != metricsList.last ? 10.0 : 0),
                            child: GestureDetector(
                              onTap: () async {
                                await Navigator.push(
                                    context,
                                    gogaitRoute(
                                        builder: (_) =>
                                            const VistaExportMetrics()));
                                setState(() {});
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: kCard,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: kGrayDark.withValues(alpha: 0.5)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(m['icon'] as IconData,
                                        color: kGray, size: 18),
                                    const SizedBox(height: 8),
                                    Text(
                                      m['value'] as String,
                                      style: TextStyle(
                                          color: m['color'] as Color,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(children: [
                                      Flexible(
                                        child: Text(m['label'] as String,
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                            style: const TextStyle(
                                                color: kGray, fontSize: 11)),
                                      ),
                                      InfoTip(
                                          titulo: m['label'] as String,
                                          texto: m['info'] as String),
                                    ]),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ))
                      .toList(),
                );
              }),
              const SizedBox(height: 32),

              GestureDetector(
                onTap: () async {
                  await Navigator.push(
                      context,
                      gogaitRoute(
                          builder: (_) => const VistaSeleccionActividad()));
                  setState(() {});
                },
                child: Container(
                  width: double.infinity,
                  height: 64,
                  decoration: BoxDecoration(
                      gradient: kGradientFull,
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.show_chart, color: Colors.white, size: 24),
                      const SizedBox(width: 10),
                      Text(
                        tr('start_analysis'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GogaitCard(
                onTap: () async {
                  await Navigator.push(
                      context,
                      gogaitRoute(
                          builder: (_) => const VistaHistorico()));
                  setState(() {});
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.history, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(tr('view_history'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---- FOOT HEATMAP WIDGET ----
// Traduce presión (0-100) a color; umbral "sin color" bajo (6, no 20) porque las medias de sesión completa caen fácilmente ahí.
Color _pressureColor(double value) {
  if (value < 6) {
    return const Color(0xFF1A1F2E);
  }
  if (value < 35) {
    return const Color(0xFFFFE082);
  }
  if (value < 50) {
    return const Color(0xFFFFC107);
  }
  if (value < 65) {
    return const Color(0xFFFF8A00);
  }
  if (value < 80) {
    return const Color(0xFFFF3D57);
  }
  if (value <= 100) {
    return const Color(0xFFFF0000);
  }
  // >100%: supera la calibración (normal en propulsión); color aparte para distinguirlo del 80-100%.
  return const Color(0xFFB026FF);
}

// Silueta de un pie coloreada según la presión de cada zona.
class FootHeatmapWidget extends StatelessWidget {
  final List<double> data;
  final String label;
  final bool isLeft;
  const FootHeatmapWidget(
      {super.key,
      required this.data,
      required this.label,
      required this.isLeft});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(label, style: const TextStyle(color: kGray, fontSize: 12)),
      const SizedBox(height: 8),
      CustomPaint(
        size: const Size(105, 150),
        painter: _FootPainter(data: data, isLeft: isLeft),
      ),
    ]);
  }
}

// Dibuja la silueta del pie a base de círculos de color por zona de presión.
class _FootPainter extends CustomPainter {
  final List<double> data;
  final bool isLeft;
  _FootPainter({required this.data, required this.isLeft});

  // Dibuja un punto de presión: un círculo de color con un halo difuminado.
  void _circle(Canvas c, double cx, double cy, double r, double value) {
    final paint = Paint()
      ..color = _pressureColor(value)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    c.drawCircle(Offset(cx, cy), r, paint);
    final paint2 = Paint()..color = _pressureColor(value);
    c.drawCircle(Offset(cx, cy), r * 0.7, paint2);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) {
      return;
    }
    // Toes
    final toes = isLeft
        ? [
            const Offset(30, 15),
            const Offset(42, 12),
            const Offset(52, 10),
            const Offset(62, 12),
            const Offset(72, 15)
          ]
        : [
            const Offset(72, 15),
            const Offset(62, 12),
            const Offset(52, 10),
            const Offset(42, 12),
            const Offset(30, 15)
          ];
    for (int i = 0; i < toes.length; i++) {
      _circle(canvas, toes[i].dx, toes[i].dy, i == 0 ? 5 : 4,
          data.length > i ? data[i] : 0);
    }

    // Ball
    final ball = isLeft
        ? [
            const Offset(28, 35),
            const Offset(40, 32),
            const Offset(52, 30),
            const Offset(64, 32),
            const Offset(74, 36),
            const Offset(32, 50),
            const Offset(48, 46),
            const Offset(64, 48),
            const Offset(70, 52)
          ]
        : [
            const Offset(74, 35),
            const Offset(64, 32),
            const Offset(52, 30),
            const Offset(40, 32),
            const Offset(28, 36),
            const Offset(70, 50),
            const Offset(54, 46),
            const Offset(38, 48),
            const Offset(32, 52)
          ];
    for (int i = 0; i < ball.length; i++) {
      _circle(canvas, ball[i].dx, ball[i].dy, i < 5 ? 7 : 6,
          data.length > 5 + i ? data[5 + i] : 0);
    }

    // Arch
    const arch = [
      Offset(40, 68),
      Offset(52, 65),
      Offset(62, 68),
      Offset(44, 82),
      Offset(58, 82)
    ];
    for (int i = 0; i < arch.length; i++) {
      _circle(canvas, arch[i].dx, arch[i].dy, 5,
          data.length > 14 + i ? data[14 + i] : 0);
    }

    // Heel
    const heel = [
      Offset(38, 100),
      Offset(51, 98),
      Offset(64, 100),
      Offset(42, 115),
      Offset(51, 118),
      Offset(60, 115),
      Offset(46, 130),
      Offset(56, 130)
    ];
    for (int i = 0; i < heel.length; i++) {
      _circle(canvas, heel[i].dx, heel[i].dy, i == 4 ? 9 : 7,
          data.length > 19 + i ? data[19 + i] : 0);
    }
  }

  @override
  bool shouldRepaint(_FootPainter old) => old.data != data;
}

// ---- BLUETOOTH CONNECTION SCREEN ----
// Flujo con las plantillas GOGAIT_XIAO_DERECHA/IZQUIERDA: comprobar Bluetooth, escanear, conectar. Si ya había una placa conectada, salta directo a éxito.
class VistaBluetooth extends StatefulWidget {
  const VistaBluetooth({super.key});
  @override
  State<VistaBluetooth> createState() => _VistaBluetoothState();
}

enum _EstadoConexion { pendiente, buscando, conectado, fallo }

String _textoEstadoConex(_EstadoConexion e) {
  switch (e) {
    case _EstadoConexion.conectado:
      return tr('status_connected');
    case _EstadoConexion.buscando:
      return tr('status_searching');
    case _EstadoConexion.fallo:
      return tr('status_not_found');
    case _EstadoConexion.pendiente:
      return tr('status_not_connected');
  }
}

class _VistaBluetoothState extends State<VistaBluetooth>
    with TickerProviderStateMixin, IdiomaListenerMixin {
  int _step =
      0; // 0:check, 1:authorize, 2:connect, 3:connecting, 4:connected, 5:failed
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  StreamSubscription<BluetoothAdapterState>? _adapterSub;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connSubDer;
  StreamSubscription<BluetoothConnectionState>? _connSubIzq;
  Timer? _timeoutTimer;

  // Estado de cada plantilla por separado: se buscan en el mismo escaneo pero conectan independientemente.
  _EstadoConexion _estadoDer = _EstadoConexion.pendiente;
  _EstadoConexion _estadoIzq = _EstadoConexion.pendiente;
  final Set<Pie> _conectandoAhora = {};

  _EstadoConexion _estadoDe(Pie pie) =>
      pie == Pie.derecha ? _estadoDer : _estadoIzq;
  void _setEstado(Pie pie, _EstadoConexion e) {
    if (pie == Pie.derecha) {
      _estadoDer = e;
    } else {
      _estadoIzq = e;
    }
  }

  bool get _algunaConectada =>
      _estadoDer == _EstadoConexion.conectado ||
      _estadoIzq == _EstadoConexion.conectado;
  bool get _ambasConectadas =>
      _estadoDer == _EstadoConexion.conectado &&
      _estadoIzq == _EstadoConexion.conectado;

  // Si ya había placas conectadas salta directo a "Conectado"; si no, vigila el Bluetooth del móvil.
  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.5, end: 1.0).animate(_pulseCtrl);
    for (final pie in Pie.values) {
      final device = bleEstado(pie).device;
      if (device != null) {
        _setEstado(pie, _EstadoConexion.conectado);
        _escucharDesconexion(device, pie);
      }
    }
    if (_algunaConectada) {
      _step = 4;
      return;
    }
    _adapterSub = FlutterBluePlus.adapterState.listen((state) {
      if (!mounted) {
        return;
      }
      if (state == BluetoothAdapterState.on) {
        setState(() => _step = 2);
      } else {
        setState(() => _step = 1);
      }
    });
  }

  void _escucharDesconexion(BluetoothDevice device, Pie pie) {
    final sub = device.connectionState.listen((s) {
      if (s == BluetoothConnectionState.disconnected && mounted) {
        setState(() {
          _setEstado(pie, _EstadoConexion.pendiente);
          if (_step == 4 && !_algunaConectada) {
            _step = 2;
          }
        });
      }
    });
    if (pie == Pie.derecha) {
      _connSubDer = sub;
    } else {
      _connSubIzq = sub;
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _adapterSub?.cancel();
    _scanSub?.cancel();
    _connSubDer?.cancel();
    _connSubIzq?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  // Pide activar el Bluetooth del sistema (solo hace falta en Android).
  Future<void> _authorize() async {
    try {
      if (Platform.isAndroid) {
        await FlutterBluePlus.turnOn();
      }
    } catch (_) {}
  }

  void _terminarEscaneo() {
    _timeoutTimer?.cancel();
    _scanSub?.cancel();
    if (FlutterBluePlus.isScanningNow) {
      FlutterBluePlus.stopScan();
    }
    if (!mounted) {
      return;
    }
    setState(() {
      for (final pie in Pie.values) {
        if (_estadoDe(pie) == _EstadoConexion.buscando) {
          _setEstado(pie, _EstadoConexion.fallo);
        }
      }
      _step = _algunaConectada ? 4 : 5;
    });
  }

  // Escanea las dos placas a la vez y conecta cada una en cuanto aparece; a los 12s sin encontrarla, marca fallida.
  Future<void> _connect() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _step = 3;
      for (final pie in Pie.values) {
        if (_estadoDe(pie) != _EstadoConexion.conectado) {
          _setEstado(pie, _EstadoConexion.buscando);
        }
      }
    });
    _timeoutTimer = Timer(const Duration(seconds: 12), _terminarEscaneo);
    await _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        for (final pie in Pie.values) {
          if (_estadoDe(pie) != _EstadoConexion.buscando ||
              _conectandoAhora.contains(pie)) {
            continue;
          }
          final id = idBlePara(pie);
          final matchNombre = r.device.platformName == id.nombre;
          final matchUUID = r.advertisementData.serviceUuids.any((u) => u
              .toString()
              .toLowerCase()
              .contains(id.servicioUuid.toLowerCase()));
          if (matchNombre || matchUUID) {
            _conectandoAhora.add(pie);
            _conectarUno(r.device, pie);
          }
        }
      }
    });
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 12));
  }

  // Conecta con una placa ya localizada, sin bloquear a la otra plantilla.
  Future<void> _conectarUno(BluetoothDevice device, Pie pie) async {
    final ok = await _conectarYSuscribirPie(device, pie);
    _conectandoAhora.remove(pie);
    if (!mounted) {
      return;
    }
    setState(() {
      _setEstado(pie, ok ? _EstadoConexion.conectado : _EstadoConexion.fallo);
      if (ok) {
        _escucharDesconexion(device, pie);
      }
      final sigueBuscando = _estadoDer == _EstadoConexion.buscando ||
          _estadoIzq == _EstadoConexion.buscando;
      if (!sigueBuscando) {
        _timeoutTimer?.cancel();
        _scanSub?.cancel();
        if (FlutterBluePlus.isScanningNow) {
          FlutterBluePlus.stopScan();
        }
        _step = _algunaConectada ? 4 : 5;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
          child: Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
              GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          color: kCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kGrayDark)),
                      child: const Icon(Icons.chevron_left,
                          color: Colors.white, size: 20))),
              Expanded(
                  child: Text(tr('device_connection'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600))),
              const SizedBox(width: 36),
            ])),
        Expanded(
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: _step == 0
                    ? const Center(
                        child: CircularProgressIndicator(color: kOrange))
                    : _step == 1
                        ? _buildAuthorize()
                        : _step == 2
                            ? _buildConnect()
                            : _step == 3
                                ? _buildConnecting()
                                : _step == 4
                                    ? _buildSuccess()
                                    : _buildFailed())),
      ])),
    );
  }

  // Paso 1: pedir al usuario que active el Bluetooth.
  Widget _buildAuthorize() => Column(children: [
        const Spacer(),
        Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0D1F3C),
                border: Border.all(color: kTeal.withValues(alpha: 0.3))),
            child: const Icon(Icons.bluetooth, color: kTeal, size: 48)),
        const SizedBox(height: 24),
        Text(tr('enable_bluetooth'),
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Text(tr('bluetooth_required'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: kGray, fontSize: 14)),
        const SizedBox(height: 32),
        GogaitCard(
            padding: const EdgeInsets.all(20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('about_insoles_title'),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15)),
              const SizedBox(height: 12),
              _WhyItem(tr('why_xiao_sensors')),
              _WhyItem(tr('why_measures_plantar')),
              _WhyItem(tr('why_sends_10ms')),
              _WhyItem(tr('why_powers_analysis')),
            ])),
        const Spacer(),
        GogaitButton(text: tr('enable_bluetooth'), onTap: _authorize),
      ]);

  // Fila de estado de un pie, reutilizada en los pasos 2 a 5.
  Widget _filaEstado(Pie pie) {
    final estado = _estadoDe(pie);
    late Color color;
    late IconData icon;
    late String texto;
    switch (estado) {
      case _EstadoConexion.conectado:
        color = kTeal;
        icon = Icons.bluetooth_connected;
        texto = tr('status_connected');
        break;
      case _EstadoConexion.buscando:
        color = kOrange;
        icon = Icons.bluetooth_searching;
        texto = tr('status_searching');
        break;
      case _EstadoConexion.fallo:
        color = kRed;
        icon = Icons.bluetooth_disabled;
        texto = tr('status_not_found');
        break;
      case _EstadoConexion.pendiente:
        color = kGray;
        icon = Icons.bluetooth;
        texto = tr('status_not_connected');
        break;
    }
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 10),
                Text(pie == Pie.derecha ? tr('insole_right') : tr('insole_left'),
                    style:
                        const TextStyle(color: Colors.white, fontSize: 14)),
              ]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(texto,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
            ]));
  }

  // Paso 2: Bluetooth ya activo, listo para pulsar "Connect Devices".
  Widget _buildConnect() => SingleChildScrollView(
          child: Column(children: [
        const SizedBox(height: 20),
        AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [
                      kOrange.withValues(alpha: 0.15 * _pulseAnim.value),
                      kRed.withValues(alpha: 0.15 * _pulseAnim.value)
                    ]),
                    border: Border.all(
                        color: kOrange.withValues(alpha: _pulseAnim.value),
                        width: 2)),
                child: Icon(Icons.bluetooth,
                    color: kOrange.withValues(alpha: _pulseAnim.value),
                    size: 48))),
        const SizedBox(height: 24),
        Text(tr('connect_smart_insoles'),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(tr('right_left_insoles'),
            style: const TextStyle(color: kGray, fontSize: 14)),
        const SizedBox(height: 24),
        GogaitCard(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              _filaEstado(Pie.derecha),
              const Divider(color: Color(0xFF374151), height: 20),
              _filaEstado(Pie.izquierda),
            ])),
        const SizedBox(height: 16),
        GogaitCard(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('about_insoles_title'),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
              const SizedBox(height: 8),
              _WhyItem(tr('why_measures_heel_metatarsal')),
              _WhyItem(tr('why_sends_ble')),
              _WhyItem(tr('why_powers_heatmap')),
            ])),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _connect,
          child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                  gradient: kGradient, borderRadius: BorderRadius.circular(16)),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(tr('connect_devices'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16)),
                  ])),
        ),
        const SizedBox(height: 20),
      ]));

  // Paso 3: escaneando/conectando; estado de cada pie por separado.
  Widget _buildConnecting() => SingleChildScrollView(
          child: Column(children: [
        const SizedBox(height: 20),
        AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [
                      kOrange.withValues(alpha: 0.15 * _pulseAnim.value),
                      kRed.withValues(alpha: 0.15 * _pulseAnim.value)
                    ]),
                    border: Border.all(
                        color: kOrange.withValues(alpha: _pulseAnim.value),
                        width: 2)),
                child: Icon(Icons.bluetooth_searching,
                    color: kOrange.withValues(alpha: _pulseAnim.value),
                    size: 48))),
        const SizedBox(height: 24),
        Text(tr('searching_for_insoles'),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(tr('waiting_up_to_12s'),
            style: const TextStyle(color: kGray, fontSize: 12)),
        const SizedBox(height: 20),
        GogaitCard(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              _filaEstado(Pie.derecha),
              const Divider(color: Color(0xFF374151), height: 20),
              _filaEstado(Pie.izquierda),
            ])),
        const SizedBox(height: 20),
      ]));

  // Paso 4: al menos una plantilla conectada.
  Widget _buildSuccess() => SingleChildScrollView(
          child: Column(children: [
        const SizedBox(height: 20),
        Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [
                  const Color(0xFF00E6A8).withValues(alpha: _ambasConectadas ? 1 : 0.5),
                  kTeal.withValues(alpha: _ambasConectadas ? 1 : 0.5)
                ])),
            child: const Icon(Icons.bluetooth_connected,
                color: Colors.white, size: 48)),
        const SizedBox(height: 24),
        Text(_ambasConectadas ? tr('both_insoles_connected') : tr('partially_connected'),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(
            _ambasConectadas
                ? tr('both_ready')
                : tr('missing_insole').replaceAll('{side}',
                    _estadoDer == _EstadoConexion.conectado
                        ? tr('side_left')
                        : tr('side_right')),
            textAlign: TextAlign.center,
            style: const TextStyle(color: kGray, fontSize: 14)),
        const SizedBox(height: 24),
        GogaitCard(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              _filaEstado(Pie.derecha),
              const Divider(color: Color(0xFF374151), height: 20),
              _filaEstado(Pie.izquierda),
            ])),
        const SizedBox(height: 20),
        if (!_ambasConectadas) ...[
          GestureDetector(
              onTap: _connect,
              child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                      color: kCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kGrayDark)),
                  child: Center(
                      child: Text(tr('search_again'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15))))),
          const SizedBox(height: 12),
        ],
        GogaitButton(
            text: tr('continue_label'), onTap: () => Navigator.pop(context)),
        const SizedBox(height: 20),
      ]));

  // Paso 5: no se encontró/no se pudo conectar con ninguna placa.
  Widget _buildFailed() => SingleChildScrollView(
          child: Column(children: [
        const SizedBox(height: 20),
        Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kRed.withValues(alpha: 0.1),
                border: Border.all(color: kRed.withValues(alpha: 0.4))),
            child: const Icon(Icons.bluetooth_disabled, color: kRed, size: 48)),
        const SizedBox(height: 24),
        Text(tr('connection_failed'),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(
            tr('could_not_find_insoles'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: kGray, fontSize: 14)),
        const SizedBox(height: 24),
        GogaitCard(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              _filaEstado(Pie.derecha),
              const Divider(color: Color(0xFF374151), height: 20),
              _filaEstado(Pie.izquierda),
            ])),
        const SizedBox(height: 20),
        GestureDetector(
            onTap: _connect,
            child: Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                    gradient: kGradient,
                    borderRadius: BorderRadius.circular(16)),
                child: Center(
                    child: Text(tr('retry'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15))))),
        if (_algunaConectada) ...[
          const SizedBox(height: 12),
          GogaitButton(
              text: tr('continue_with_1_insole'),
              onTap: () => Navigator.pop(context)),
        ],
        const SizedBox(height: 12),
        GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(tr('back'),
                    style: const TextStyle(color: kGray, fontSize: 14)))),
        const SizedBox(height: 20),
      ]));
}

// Línea con viñeta para las listas "About GOGAIT Smart Insoles".
class _WhyItem extends StatelessWidget {
  final String text;
  const _WhyItem(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('• ', style: TextStyle(color: kOrange, fontSize: 14)),
          Expanded(
              child: Text(text,
                  style: const TextStyle(color: kGray, fontSize: 13))),
        ]),
      );
}

// ---- ACTIVITY TYPE SELECTION SCREEN (previa a la calibración) ----
// Elegir el tipo prellena tipo/título de sesión en VistaResumen (tipoInicial). La calibración es la misma para los tres, con un salto que también vale para correr.
class VistaSeleccionActividad extends StatelessWidget {
  const VistaSeleccionActividad({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLang>(
        valueListenable: appLang,
        builder: (context, _, __) {
    final tipos = [
      {
        'tipo': 'walking',
        'icon': Icons.directions_walk,
        'titulo': tr('activity_walk'),
        'desc': tr('activity_walk_desc'),
      },
      {
        'tipo': 'running',
        'icon': Icons.directions_run_outlined,
        'titulo': tr('activity_run'),
        'desc': tr('activity_run_desc'),
      },
      {
        'tipo': 'trail',
        'icon': Icons.landscape_outlined,
        'titulo': tr('activity_trail'),
        'desc': tr('activity_trail_desc'),
      },
    ];
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
          child: Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
              GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          color: kCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kGrayDark)),
                      child: const Icon(Icons.chevron_left,
                          color: Colors.white, size: 20))),
              const SizedBox(width: 12),
              Expanded(
                child: Text(tr('select_activity_title'),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600)),
              ),
            ])),
        Expanded(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          tr('select_activity_subtitle'),
                          style: const TextStyle(color: kGray, fontSize: 13)),
                      const SizedBox(height: 20),
                      for (final t in tipos) ...[
                        GogaitCard(
                            onTap: () => Navigator.push(
                                context,
                                gogaitRoute(
                                    builder: (_) => VistaPreparacion(
                                        tipoActividad:
                                            t['tipo'] as String))),
                            padding: const EdgeInsets.all(16),
                            child: Row(children: [
                              Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                      color: kOrange.withValues(alpha: 0.1),
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                  child: Icon(t['icon'] as IconData,
                                      color: kOrange, size: 22)),
                              const SizedBox(width: 14),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(t['titulo'] as String,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 16)),
                                        const SizedBox(height: 2),
                                        Text(t['desc'] as String,
                                            style: const TextStyle(
                                                color: kGray, fontSize: 12)),
                                      ])),
                              const Icon(Icons.chevron_right,
                                  color: kGray, size: 20),
                            ])),
                        const SizedBox(height: 12),
                      ],
                    ]))),
      ])),
    );
        });
  }
}

// ---- INSOLE PREPARATION SCREEN (splash obligatorio) ----
// Paso obligatorio antes de Live Analysis: conectar y calibrar de cero cada vez (histéresis de la fibra y peso del usuario cambian); al completar navega sola a VistaActividad.
class VistaPreparacion extends StatefulWidget {
  final String tipoActividad;
  const VistaPreparacion({super.key, required this.tipoActividad});
  @override
  State<VistaPreparacion> createState() => _VistaPreparacionState();
}

enum _TipoEstadoBle { noConectado, buscando, conectado, noEncontrado, desconectado }

class _VistaPreparacionState extends State<VistaPreparacion> with IdiomaListenerMixin {
  // Se calibra primero el pie derecho y luego el izquierdo; ver _cambiarAPie.
  Pie _pieActual = Pie.derecha;
  bool _conectado = false, _conectando = false, _escaneando = false;
  StreamSubscription<BluetoothConnectionState>? _connSub;

  // Guardado como "tipo" + parámetro (no texto traducido) para que _estadoBleTexto refleje el idioma actual.
  _TipoEstadoBle _tipoEstadoBle = _TipoEstadoBle.noConectado;
  String? _nombreBuscando;

  String get _estadoBleTexto {
    switch (_tipoEstadoBle) {
      case _TipoEstadoBle.noConectado:
        return tr('status_not_connected');
      case _TipoEstadoBle.buscando:
        return tr('searching_device').replaceAll('{name}', _nombreBuscando ?? '');
      case _TipoEstadoBle.conectado:
        return _insoleConectadoMsg(_pieActual);
      case _TipoEstadoBle.noEncontrado:
        return tr('insole_not_found');
      case _TipoEstadoBle.desconectado:
        return tr('disconnected');
    }
  }

  String _insoleConectadoMsg(Pie pie) =>
      tr('insole_side_connected').replaceAll('{side}', etiquetaPie(pie));

  // Solo se pide saltar en Run/Trekking: andar ya ronda 1.1-1.2x el peso corporal en el pico, basta apoyo en calma.
  bool get _conSaltos => widget.tipoActividad != 'walking';

  // Pasos con saltos: 0 nada·1 reposo·2 calma·3 +salto·4 talón calma·5 +salto·6 punta calma·7 +salto.
  // Sin saltos: 0 nada·1 reposo·2 carga·3 talón·4 punta. Con salto, se guarda el pico más alto de las dos capturas.
  int _pasoCalibracion = 0;
  bool _muestreando = false;
  StreamSubscription<List<int>>? _muestreoSub;
  final List<double> _muestras = [];
  double? _adcReposo,
      _adcCargaPie,
      _adcCarga,
      _adcTalonPie,
      _adcTalon,
      _adcPuntaPie,
      _adcPunta;
  String? _errorCalibracion;

  // Suscripción BLE permanente (no la de 2s de _capturarPaso) para feedback en vivo antes de pulsar "Capture".
  StreamSubscription<List<int>>? _liveSub;
  double _lecturaEnVivo = 0;
  double _adcCrudoEnVivo = 0;
  DateTime? _ultimoRefrescoLive;

  // Presión en vivo con reposo/carga de ESTA calibración (no la guardada vía adcAPresion); null hasta tener ambas.
  double? get _presionEnVivoCalibrada {
    if (_adcReposo == null || _adcCarga == null) {
      return null;
    }
    final rango = _adcReposo! - _adcCarga!;
    if (rango <= 0) {
      return 0;
    }
    final presion = 100 * (_adcReposo! - _adcCrudoEnVivo) / rango;
    return presion < 0 ? 0 : presion;
  }

  @override
  void initState() {
    super.initState();
    final estado = bleEstado(_pieActual);
    if (estado.device != null && estado.characteristic != null) {
      _conectado = true;
      _tipoEstadoBle = _TipoEstadoBle.conectado;
      _escucharDesconexion();
      _iniciarLive();
    }
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _muestreoSub?.cancel();
    _liveSub?.cancel();
    super.dispose();
  }

  void _escucharDesconexion() {
    _connSub?.cancel();
    final device = bleEstado(_pieActual).device;
    if (device == null) {
      return;
    }
    _connSub = device.connectionState.listen((s) {
      if (s == BluetoothConnectionState.disconnected && mounted) {
        setState(() {
          _conectado = false;
          _tipoEstadoBle = _TipoEstadoBle.desconectado;
        });
      }
    });
  }

  // Escucha el ADC crudo (throttled a ~60/s) para reflejar al instante en el mapa de calor qué zona se presiona.
  void _iniciarLive() {
    _liveSub?.cancel();
    _liveSub = bleEstado(_pieActual).characteristic!.lastValueStream.listen((data) {
      final v = double.tryParse(utf8.decode(data).trim());
      if (v == null || !mounted) {
        return;
      }
      final ahora = DateTime.now();
      if (_ultimoRefrescoLive == null ||
          ahora.difference(_ultimoRefrescoLive!) >=
              const Duration(milliseconds: 16)) {
        _ultimoRefrescoLive = ahora;
        setState(() {
          _lecturaEnVivo = adcAPresion(v, _pieActual);
          _adcCrudoEnVivo = v;
        });
      }
    });
  }

  // Reparte la lectura en vivo entre talón/metatarso según el sub-paso, para resaltar solo la zona que toca.
  List<double> get _heatmapEnVivo {
    // Solo se llama con referencias ya listas (ver condición en build()), así que _presionEnVivoCalibrada no es null aquí.
    final presion = _presionEnVivoCalibrada ?? _lecturaEnVivo;
    double talon = presion, meta = presion;
    final heelActivo = _conSaltos
        ? (_pasoCalibracion == 3 || _pasoCalibracion == 4)
        : _pasoCalibracion == 2;
    final forefootActivo = _conSaltos
        ? (_pasoCalibracion == 5 || _pasoCalibracion == 6)
        : _pasoCalibracion == 3;
    if (heelActivo) {
      meta = 0; // sub-paso(s) "solo talón"
    } else if (forefootActivo) {
      talon = 0; // sub-paso(s) "solo punta"
    }
    return List.generate(30, (i) {
      if (i < 5) {
        return meta;
      }
      if (i < 14) {
        return meta * 0.8;
      }
      if (i < 19) {
        return 10;
      }
      return talon;
    });
  }

  // Si la lectura en vivo coincide con lo esperado en el sub-paso (sin presión = pie en aire; resto = contacto).
  bool get _faseConfirmada {
    final contacto = _lecturaEnVivo >= kUmbralContacto;
    return _pasoCalibracion == 0 ? !contacto : contacto;
  }

  // Texto de confirmación bajo el mapa de calor, según el sub-paso activo.
  String get _etiquetaFaseCalib {
    final contacto = _lecturaEnVivo >= kUmbralContacto;
    if (!_conSaltos) {
      switch (_pasoCalibracion) {
        case 0:
          return contacto
              ? tr('phase_pressure_lift')
              : tr('phase_foot_lifted');
        case 1:
          return contacto
              ? tr('phase_full_foot_pressed')
              : tr('phase_waiting_full_foot');
        case 2:
          return contacto ? tr('phase_heel_pressed') : tr('phase_waiting_heel');
        case 3:
          return contacto
              ? tr('phase_forefoot_pressed')
              : tr('phase_waiting_forefoot');
        default:
          return tr('phase_calibration_complete');
      }
    }
    switch (_pasoCalibracion) {
      case 0:
        return contacto ? tr('phase_pressure_lift') : tr('phase_foot_lifted');
      case 1:
        return contacto ? tr('phase_full_foot_pressed') : tr('phase_waiting_full_foot');
      case 2:
        return contacto ? tr('phase_hop_detected') : tr('phase_waiting_hop');
      case 3:
        return contacto ? tr('phase_heel_pressed') : tr('phase_waiting_heel');
      case 4:
        return contacto ? tr('phase_hop_detected') : tr('phase_waiting_heel_hop');
      case 5:
        return contacto ? tr('phase_forefoot_pressed') : tr('phase_waiting_forefoot');
      case 6:
        return contacto ? tr('phase_hop_detected') : tr('phase_waiting_forefoot_hop');
      default:
        return tr('phase_calibration_complete');
    }
  }

  // Escanea/conecta la placa del pie actual (mismo criterio que el resto de la app). No desconecta al salir: la conexión queda viva globalmente.
  Future<void> _conectar() async {
    if (_escaneando || _conectando || _conectado) {
      return;
    }
    setState(() {
      _escaneando = true;
      _tipoEstadoBle = _TipoEstadoBle.buscando;
      _nombreBuscando = idBlePara(_pieActual).nombre;
    });
    final ok = await escanearYConectarPie(_pieActual,
        timeout: const Duration(seconds: 15));
    if (!mounted) {
      return;
    }
    if (ok) {
      _escucharDesconexion();
      setState(() {
        _escaneando = false;
        _conectando = false;
        _conectado = true;
        _tipoEstadoBle = _TipoEstadoBle.conectado;
      });
      _iniciarLive();
    } else {
      setState(() {
        _escaneando = false;
        _conectando = false;
        _tipoEstadoBle = _TipoEstadoBle.noEncontrado;
      });
    }
  }

  // Deja lista la pantalla para el siguiente pie: resetea el asistente y, si ya estaba conectada, arranca su feedback en vivo.
  void _cambiarAPie(Pie nuevo) {
    _liveSub?.cancel();
    _connSub?.cancel();
    _muestreoSub?.cancel();
    if (!mounted) {
      return;
    }
    setState(() {
      _pieActual = nuevo;
      _pasoCalibracion = 0;
      _muestras.clear();
      _adcReposo = null;
      _adcCargaPie = null;
      _adcCarga = null;
      _adcTalonPie = null;
      _adcTalon = null;
      _adcPuntaPie = null;
      _adcPunta = null;
      _errorCalibracion = null;
      _lecturaEnVivo = 0;
      _muestreando = false;
      final estado = bleEstado(nuevo);
      if (estado.device != null && estado.characteristic != null) {
        _conectado = true;
        _conectando = false;
        _escaneando = false;
        _tipoEstadoBle = _TipoEstadoBle.conectado;
      } else {
        _conectado = false;
        _conectando = false;
        _escaneando = false;
        _tipoEstadoBle = _TipoEstadoBle.noConectado;
      }
    });
    if (_conectado) {
      _escucharDesconexion();
      _iniciarLive();
    }
  }

  // Muestrea el ADC ~2s: paso 1 usa el promedio (reposo), el resto el mínimo (ADC más bajo = mayor presión); al final guarda y pasa al siguiente pie.
  void _capturarPaso(int paso) {
    final char = bleEstado(_pieActual).characteristic;
    if (char == null || _muestreando) {
      return;
    }
    setState(() {
      _muestreando = true;
      _errorCalibracion = null;
      _muestras.clear();
    });
    _muestreoSub = char.lastValueStream.listen((data) {
      final v = double.tryParse(utf8.decode(data).trim());
      if (v != null) {
        _muestras.add(v);
      }
    });
    Future.delayed(const Duration(seconds: 2), () async {
      await _muestreoSub?.cancel();
      if (!mounted) {
        return;
      }
      if (_muestras.isEmpty) {
        setState(() {
          _muestreando = false;
          _errorCalibracion = tr('err_no_data_insole');
        });
        return;
      }
      if (paso == 1) {
        _adcReposo = _muestras.reduce((a, b) => a + b) / _muestras.length;
        setState(() {
          _muestreando = false;
          _pasoCalibracion = 1;
        });
        return;
      }
      final minimo = _muestras.reduce((a, b) => a < b ? a : b);
      if (!_conSaltos) {
        // Secuencia corta sin salto: 1 reposo, 2 carga, 3 talón, 4 punta.
        if (paso == 2) {
          if ((_adcReposo! - minimo).abs() < 20) {
            setState(() {
              _muestreando = false;
              _errorCalibracion = tr('err_not_enough_difference');
            });
            return;
          }
          _adcCarga = minimo;
          setState(() {
            _muestreando = false;
            _pasoCalibracion = 2;
          });
          return;
        }
        if (paso == 3) {
          _adcTalon = minimo;
          setState(() {
            _muestreando = false;
            _pasoCalibracion = 3;
          });
          return;
        }
        // paso 4: solo punta, último punto de la calibración de este pie.
        _adcPunta = minimo;
        await guardarCalibracion(
            _pieActual, _adcReposo!, _adcCarga!, _adcTalon!, _adcPunta!);
        if (!mounted) {
          return;
        }
        setState(() {
          _muestreando = false;
          _pasoCalibracion = 4;
        });
        _pasarASiguientePieOResumen();
        return;
      }
      if (paso == 2) {
        if ((_adcReposo! - minimo).abs() < 20) {
          setState(() {
            _muestreando = false;
            _errorCalibracion = tr('err_not_enough_difference');
          });
          return;
        }
        // Candidato de pie en calma; el salto del paso 3 da un pico más realista, se guarda el más alto de los dos.
        _adcCargaPie = minimo;
        setState(() {
          _muestreando = false;
          _pasoCalibracion = 2;
        });
        return;
      }
      if (paso == 3) {
        // Sin validar "salto insuficiente" (la calma ya validó); carga final = el pico más alto entre calma y salto.
        _adcCarga = minimo < _adcCargaPie! ? minimo : _adcCargaPie!;
        setState(() {
          _muestreando = false;
          _pasoCalibracion = 3;
        });
        return;
      }
      if (paso == 4) {
        // Candidato de talón en apoyo estático (inclinado hacia atrás, sin saltar aún).
        _adcTalonPie = minimo;
        setState(() {
          _muestreando = false;
          _pasoCalibracion = 4;
        });
        return;
      }
      if (paso == 5) {
        // Talón final = pico más alto entre apoyo estático y salto sobre el talón (mismo motivo que la carga).
        _adcTalon = minimo < _adcTalonPie! ? minimo : _adcTalonPie!;
        setState(() {
          _muestreando = false;
          _pasoCalibracion = 5;
        });
        return;
      }
      if (paso == 6) {
        // Candidato de punta en apoyo estático (inclinado hacia delante).
        _adcPuntaPie = minimo;
        setState(() {
          _muestreando = false;
          _pasoCalibracion = 6;
        });
        return;
      }
      // paso 7: salto sobre la punta, último punto de la calibración de
      // este pie.
      _adcPunta = minimo < _adcPuntaPie! ? minimo : _adcPuntaPie!;
      await guardarCalibracion(
          _pieActual, _adcReposo!, _adcCarga!, _adcTalon!, _adcPunta!);
      if (!mounted) {
        return;
      }
      setState(() {
        _muestreando = false;
        _pasoCalibracion = 7;
      });
      _pasarASiguientePieOResumen();
    });
  }

  // Al completar la calibración de un pie: si era el derecho, pasa a
  // calibrar el izquierdo; si ya eran los dos, entra en Live Analysis.
  void _pasarASiguientePieOResumen() {
    final piePrevio = _pieActual;
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) {
        return;
      }
      if (piePrevio == Pie.derecha) {
        _cambiarAPie(Pie.izquierda);
      } else {
        Navigator.pushReplacement(
            context,
            gogaitRoute(
                builder: (_) =>
                    VistaActividad(tipoActividad: widget.tipoActividad)));
      }
    });
  }

  // Pone a null los valores desde el paso [pasoObjetivo] en adelante, sin
  // tocar lo anterior. La numeración depende de si hay saltos (_conSaltos).
  void _limpiarDesde(int pasoObjetivo) {
    final limpiadores = _conSaltos
        ? <int, VoidCallback>{
            1: () => _adcReposo = null,
            2: () => _adcCargaPie = null,
            3: () => _adcCarga = null,
            4: () => _adcTalonPie = null,
            5: () => _adcTalon = null,
            6: () => _adcPuntaPie = null,
            7: () => _adcPunta = null,
          }
        : <int, VoidCallback>{
            1: () => _adcReposo = null,
            2: () => _adcCarga = null,
            3: () => _adcTalon = null,
            4: () => _adcPunta = null,
          };
    for (final entry in limpiadores.entries) {
      if (entry.key >= pasoObjetivo) {
        entry.value();
      }
    }
  }

  // Repite un sub-paso sin reiniciar los anteriores (ver _limpiarDesde).
  void _rehacerPaso(int paso) {
    if (_muestreando) {
      return;
    }
    setState(() {
      _limpiarDesde(paso);
      _pasoCalibracion = paso - 1;
      _errorCalibracion = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
          child: Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
              GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          color: kCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kGrayDark)),
                      child: const Icon(Icons.chevron_left,
                          color: Colors.white, size: 20))),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(tr('prepare_insole'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600))),
            ])),
        Expanded(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          tr('prepare_insole_desc'),
                          style: const TextStyle(color: kGray, fontSize: 13)),
                      const SizedBox(height: 14),
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                              color: kOrange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: kOrange.withValues(alpha: 0.3))),
                          child: Row(children: [
                            const Icon(Icons.rule, color: kOrange, size: 16),
                            const SizedBox(width: 8),
                            Text(
                                tr('calibrating_foot')
                                    .replaceAll('{side}', etiquetaPie(_pieActual)),
                                style: const TextStyle(
                                    color: kOrange,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ])),
                      const SizedBox(height: 14),
                      _pasoUI(
                          numero: 1,
                          titulo: tr('put_on_insole'),
                          hecho: true,
                          contenido: Text(
                              tr('fit_snugly'),
                              style: const TextStyle(color: kGray, fontSize: 13))),
                      const SizedBox(height: 14),
                      _pasoUI(
                          numero: 2,
                          titulo: tr('connect_via_bluetooth'),
                          hecho: _conectado,
                          contenido: _conectado
                              ? Text(_insoleConectadoMsg(_pieActual),
                                  style:
                                      const TextStyle(color: kTeal, fontSize: 13))
                              : Row(children: [
                                  Expanded(
                                      child: Text(_estadoBleTexto,
                                          style: TextStyle(
                                              color: _escaneando
                                                  ? kOrange
                                                  : kGray,
                                              fontSize: 13))),
                                  if (_escaneando || _conectando)
                                    const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2, color: kOrange))
                                  else
                                    GestureDetector(
                                        onTap: _conectar,
                                        child: Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 6),
                                            decoration: BoxDecoration(
                                                gradient: kGradient,
                                                borderRadius:
                                                    BorderRadius.circular(8)),
                                            child: Text(tr('connect_button'),
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.w600)))),
                                ])),
                      const SizedBox(height: 14),
                      Opacity(
                          opacity: _conectado ? 1 : 0.4,
                          child: IgnorePointer(
                              ignoring: !_conectado,
                              child: _pasoUI(
                                  numero: 3,
                                  titulo: tr('calibrate_to_weight'),
                                  hecho: _pasoCalibracion == (_conSaltos ? 7 : 4),
                                  contenido: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (_conectado) ...[
                                          Builder(builder: (context) {
                                            final presionCalibrada =
                                                _presionEnVivoCalibrada;
                                            final calibrando =
                                                presionCalibrada != null;
                                            return Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  if (calibrando)
                                                    Center(
                                                        child:
                                                            FootHeatmapWidget(
                                                                data:
                                                                    _heatmapEnVivo,
                                                                label:
                                                                    etiquetaPie(_pieActual),
                                                                isLeft: _pieActual ==
                                                                    Pie.izquierda))
                                                  else
                                                    // Sin reposo+carga de esta sesión no hay referencia fiable todavía.
                                                    Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(20),
                                                        alignment:
                                                            Alignment.center,
                                                        decoration: BoxDecoration(
                                                            color: kCard,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        16),
                                                            border: Border.all(
                                                                color:
                                                                    kGrayDark)),
                                                        child: Text(
                                                            tr('heatmap_pending'),
                                                            textAlign:
                                                                TextAlign
                                                                    .center,
                                                            style: const TextStyle(
                                                                color: kGray,
                                                                fontSize:
                                                                    12))),
                                                  const SizedBox(height: 8),
                                                  Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        if (_faseConfirmada)
                                                          const Icon(
                                                              Icons
                                                                  .check_circle,
                                                              color: kTeal,
                                                              size: 14),
                                                        if (_faseConfirmada)
                                                          const SizedBox(
                                                              width: 6),
                                                        Flexible(
                                                          child: Text(
                                                              _etiquetaFaseCalib,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              maxLines: 1,
                                                              style: TextStyle(
                                                                  color: _faseConfirmada
                                                                      ? kTeal
                                                                      : kGray,
                                                                  fontSize: 13,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600)),
                                                        ),
                                                        // % respecto a la carga completa de esta sesión.
                                                        if (calibrando) ...[
                                                          const SizedBox(
                                                              width: 8),
                                                          Text(
                                                              '${presionCalibrada.round()}%',
                                                              style: const TextStyle(
                                                                  color:
                                                                      kOrange,
                                                                  fontSize: 13,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700)),
                                                        ],
                                                      ]),
                                                  const SizedBox(height: 4),
                                                  // ADC crudo sin calibrar, para detectar visualmente un sensor enganchado.
                                                  Text(
                                                      tr('raw_adc').replaceAll(
                                                          '{n}', '${_adcCrudoEnVivo.round()}'),
                                                      style: const TextStyle(
                                                          color: kGray,
                                                          fontSize: 11)),
                                                  const SizedBox(height: 14),
                                                ]);
                                          }),
                                        ],
                                        // Reinicia los 4/7 pasos desde cero (alternativa a repetir un sub-paso con "Redo").
                                        if (_pasoCalibracion > 0 &&
                                            _pasoCalibracion <
                                                (_conSaltos ? 7 : 4))
                                          Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 10),
                                              child: GestureDetector(
                                                  onTap: _muestreando
                                                      ? null
                                                      : () =>
                                                          _rehacerPaso(1),
                                                  child: Text(
                                                      tr('restart_calibration_foot'),
                                                      style: const TextStyle(
                                                          color: kGray,
                                                          fontSize: 12,
                                                          decoration:
                                                              TextDecoration
                                                                  .underline)))),
                                        _subpasoCalibracion(
                                            texto: tr('substep_no_pressure'),
                                            hecho: _pasoCalibracion >= 1,
                                            activo: _pasoCalibracion == 0,
                                            onTap: () => _capturarPaso(1),
                                            onRedo: () => _rehacerPaso(1)),
                                        const SizedBox(height: 10),
                                        _subpasoCalibracion(
                                            texto: tr('substep_full_pressure'),
                                            hecho: _pasoCalibracion >= 2,
                                            activo: _pasoCalibracion == 1,
                                            onTap: () => _capturarPaso(2),
                                            onRedo: () => _rehacerPaso(2)),
                                        if (_conSaltos) ...[
                                          const SizedBox(height: 10),
                                          _subpasoCalibracion(
                                              texto: tr('substep_hop'),
                                              hecho: _pasoCalibracion >= 3,
                                              activo: _pasoCalibracion == 2,
                                              onTap: () => _capturarPaso(3),
                                              onRedo: () => _rehacerPaso(3)),
                                        ],
                                        const SizedBox(height: 10),
                                        _subpasoCalibracion(
                                            texto: tr('substep_heel_only'),
                                            hecho: _pasoCalibracion >=
                                                (_conSaltos ? 4 : 3),
                                            activo: _pasoCalibracion ==
                                                (_conSaltos ? 3 : 2),
                                            onTap: () => _capturarPaso(
                                                _conSaltos ? 4 : 3),
                                            onRedo: () => _rehacerPaso(
                                                _conSaltos ? 4 : 3)),
                                        if (_conSaltos) ...[
                                          const SizedBox(height: 10),
                                          _subpasoCalibracion(
                                              texto: tr('substep_heel_hop'),
                                              hecho: _pasoCalibracion >= 5,
                                              activo: _pasoCalibracion == 4,
                                              onTap: () => _capturarPaso(5),
                                              onRedo: () => _rehacerPaso(5)),
                                        ],
                                        const SizedBox(height: 10),
                                        _subpasoCalibracion(
                                            texto: tr('substep_forefoot_only'),
                                            hecho: _pasoCalibracion >=
                                                (_conSaltos ? 6 : 4),
                                            activo: _pasoCalibracion ==
                                                (_conSaltos ? 5 : 3),
                                            onTap: () => _capturarPaso(
                                                _conSaltos ? 6 : 4),
                                            onRedo: () => _rehacerPaso(
                                                _conSaltos ? 6 : 4)),
                                        if (_conSaltos) ...[
                                          const SizedBox(height: 10),
                                          _subpasoCalibracion(
                                              texto: tr('substep_forefoot_hop'),
                                              hecho: _pasoCalibracion >= 7,
                                              activo: _pasoCalibracion == 6,
                                              onTap: () => _capturarPaso(7),
                                              onRedo: () => _rehacerPaso(7)),
                                        ],
                                        if (_errorCalibracion != null) ...[
                                          const SizedBox(height: 10),
                                          Text(_errorCalibracion!,
                                              style: const TextStyle(
                                                  color: kRed, fontSize: 12)),
                                        ],
                                        if (_pasoCalibracion ==
                                            (_conSaltos ? 7 : 4)) ...[
                                          const SizedBox(height: 10),
                                          Text(
                                              _pieActual == Pie.derecha
                                                  ? tr('right_foot_calibrated')
                                                  : tr('calibrated_entering_live'),
                                              style: const TextStyle(
                                                  color: kTeal, fontSize: 13)),
                                        ],
                                      ])))),
                    ]))),
      ])),
    );
  }

  // Tarjeta de paso numerado, con marca de "hecho" cuando corresponde.
  Widget _pasoUI(
      {required int numero,
      required String titulo,
      required bool hecho,
      required Widget contenido}) {
    return GogaitCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: hecho ? kTeal : kGrayDark, shape: BoxShape.circle),
            child: hecho
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : Text('$numero',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600))),
        const SizedBox(width: 10),
        Expanded(
          child: Text(titulo,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
        ),
      ]),
      const SizedBox(height: 10),
      contenido,
    ]));
  }

  // Fila de un sub-paso: botón "Capturar" deshabilitado hasta que le toca o mientras muestrea.
  Widget _subpasoCalibracion(
      {required String texto,
      required bool hecho,
      required bool activo,
      required VoidCallback onTap,
      VoidCallback? onRedo}) {
    return Row(children: [
      Icon(hecho ? Icons.check_circle : Icons.circle_outlined,
          color: hecho ? kTeal : kGray, size: 18),
      const SizedBox(width: 8),
      Expanded(
          child: Text(texto,
              style: TextStyle(
                  color: hecho ? Colors.white : kGray, fontSize: 13))),
      if (!hecho)
        GestureDetector(
            onTap: activo && !_muestreando ? onTap : null,
            child: Opacity(
                opacity: activo ? 1 : 0.4,
                child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: kCard,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: kOrange)),
                    child: _muestreando && activo
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: kOrange))
                        : Text(tr('capture_button'),
                            style: const TextStyle(
                                color: kOrange,
                                fontSize: 12,
                                fontWeight: FontWeight.w600))))),
      // Paso hecho se puede repetir sin perder los demás (ver _rehacerPaso).
      if (hecho && onRedo != null)
        GestureDetector(
            onTap: _muestreando ? null : onRedo,
            child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: kCard,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kGrayDark)),
                child: Text(tr('redo_button'),
                    style: const TextStyle(
                        color: kGray,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)))),
    ]);
  }
}

// Detector de fase de marcha por pie, curva en "M": Heel Strike (1er pico) -> Midstance (valle) -> Propulsion (2º pico) -> Swing.
class _EstadoMarcha {
  String fase = 'Swing';
  double ultimaPresion = 0;
  int direccion = 0; // -1 bajando, 0 inicial, 1 subiendo
  int muestrasEnDireccion = 0;
  int pasos = 0;
  final List<DateTime> tiemposPaso = [];
}

// ---- LIVE ACTIVITY SCREEN ----
// Cronómetro de sesión, heatmap de presión en tiempo real y conexión BLE (propia o heredada).
class VistaActividad extends StatefulWidget {
  final String tipoActividad;
  const VistaActividad({super.key, this.tipoActividad = 'running'});
  @override
  State<VistaActividad> createState() => _VistaActividadState();
}

class _VistaActividadState extends State<VistaActividad> with IdiomaListenerMixin {
  int _seg = 0;
  Timer? _timerCrono;
  bool _running = false, _paused = false;
  StreamSubscription<List<int>>? _notifySubDer, _notifySubIzq;
  StreamSubscription<BluetoothConnectionState>? _connSubDer, _connSubIzq;
  _EstadoConexion _estadoConexDer = _EstadoConexion.pendiente;
  _EstadoConexion _estadoConexIzq = _EstadoConexion.pendiente;
  _EstadoConexion _estadoConexDe(Pie pie) =>
      pie == Pie.derecha ? _estadoConexDer : _estadoConexIzq;
  void _setEstadoConex(Pie pie, _EstadoConexion e) {
    if (pie == Pie.derecha) {
      _estadoConexDer = e;
    } else {
      _estadoConexIzq = e;
    }
  }

  bool get _algunaConectada =>
      _estadoConexDer == _EstadoConexion.conectado ||
      _estadoConexIzq == _EstadoConexion.conectado;
  bool get _ambasConectadas =>
      _estadoConexDer == _EstadoConexion.conectado &&
      _estadoConexIzq == _EstadoConexion.conectado;

  // Distancia recorrida medida por GPS, independiente de los sensores de presión.
  StreamSubscription<Position>? _posSub;
  Position? _ultimaPosicion;
  double _distanciaMetros = 0;
  // Trazado: una entrada por posición GPS, no por muestra (100Hz sería excesivo); comparte 'seg' con _datosSesion.
  final List<Map<String, dynamic>> _recorrido = [];
  double _presionTalonIzq = 0, _presionMetaIzq = 0;
  double _presionTalonDer = 0, _presionMetaDer = 0;
  final List<Map<String, dynamic>> _datosSesion = [];
  DateTime? _ultimoRefrescoUi;

  // Orden izq->der (no el de Pie.values), igual que el heatmap, para que la etiqueta de fase corresponda.
  static const List<Pie> _kOrdenPies = [Pie.izquierda, Pie.derecha];

  // Presión instantánea de un pie (0-100): talón+metatarso reconstruye la lectura real.
  double _presionActual(Pie pie) => pie == Pie.derecha
      ? _presionTalonDer + _presionMetaDer
      : _presionTalonIzq + _presionMetaIzq;

  // Detector de fase de marcha y pasos, uno por pie (ver _EstadoMarcha).
  final _EstadoMarcha _marchaDer = _EstadoMarcha();
  final _EstadoMarcha _marchaIzq = _EstadoMarcha();
  _EstadoMarcha _marcha(Pie pie) => pie == Pie.derecha ? _marchaDer : _marchaIzq;
  static const int _kMuestrasParaConfirmar = 3;
  static const Duration _kVentanaCadencia = Duration(seconds: 10);

  // Reparte presión en 30 puntos según wTalon (ver _pesoTalon): dedos/bola=metatarso, talón=talón, arco=resto (máx en Midstance); sin suavizado, cambia en seco con la fase.
  List<double> _heatmapDesdeReparto(double presion, double wTalon) {
    // Bajo el umbral de contacto es ruido (pie en el aire): se apaga del todo en vez de teñir el mapa.
    if (presion < kUmbralContacto) {
      return List.filled(30, 0);
    }
    final talon = presion * wTalon;
    final meta = presion * (1 - wTalon);
    final arco = presion * (1 - 2 * (wTalon - 0.5).abs());
    return List.generate(30, (i) {
      if (i < 5) {
        return meta;
      }
      if (i < 14) {
        return meta * 0.8;
      }
      if (i < 19) {
        return arco;
      }
      return talon;
    });
  }

  // Heatmap en vivo del pie izquierdo (ver _heatmapDesdeReparto).
  List<double> get _leftData => _heatmapDesdeReparto(
      _presionActual(Pie.izquierda), _pesoTalon(Pie.izquierda));
  // Igual que _leftData pero para el pie derecho.
  List<double> get _rightData => _heatmapDesdeReparto(
      _presionActual(Pie.derecha), _pesoTalon(Pie.derecha));

  // Si ya había placas conectadas (VistaBluetooth/VistaPreparacion) reutiliza esas conexiones; si no, se conecta desde aquí.
  @override
  void initState() {
    super.initState();
    var algunaYaConectada = false;
    for (final pie in Pie.values) {
      final estado = bleEstado(pie);
      if (estado.device != null && estado.characteristic != null) {
        _setEstadoConex(pie, _EstadoConexion.conectado);
        _suscribirNotify(pie);
        _escucharDesconexion(pie);
        algunaYaConectada = true;
      }
    }
    if (algunaYaConectada) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !_running) {
          _iniciarTimer();
        }
      });
    }
  }

  // Se suscribe a las notificaciones de presión de la placa de un pie.
  void _suscribirNotify(Pie pie) {
    final char = bleEstado(pie).characteristic;
    if (char == null) {
      return;
    }
    final sub = char.lastValueStream.listen((data) => _procesarDatos(data, pie));
    if (pie == Pie.derecha) {
      _notifySubDer?.cancel();
      _notifySubDer = sub;
    } else {
      _notifySubIzq?.cancel();
      _notifySubIzq = sub;
    }
  }

  // Escucha la desconexión de la placa de un pie para reflejarlo en la UI.
  void _escucharDesconexion(Pie pie) {
    final device = bleEstado(pie).device;
    if (device == null) {
      return;
    }
    final sub = device.connectionState.listen((s) {
      if (s == BluetoothConnectionState.disconnected && mounted) {
        setState(() => _setEstadoConex(pie, _EstadoConexion.pendiente));
      }
    });
    if (pie == Pie.derecha) {
      _connSubDer?.cancel();
      _connSubDer = sub;
    } else {
      _connSubIzq?.cancel();
      _connSubIzq = sub;
    }
  }

  // Arranca (o reanuda) el cronómetro de duración de la sesión.
  void _iniciarTimer() {
    _timerCrono = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _seg++);
      }
    });
    setState(() => _running = true);
    if (_posSub == null) {
      _iniciarSeguimientoUbicacion();
    }
  }

  // Pide permiso de ubicación y arranca el GPS que suma distancia entre posiciones; sin permiso/GPS, se queda a 0 sin bloquear la sesión.
  Future<void> _iniciarSeguimientoUbicacion() async {
    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    if (permiso == LocationPermission.denied ||
        permiso == LocationPermission.deniedForever) {
      return;
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      return;
    }
    if (!mounted) {
      return;
    }
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3, // ignora ruido GPS por debajo de 3m
      ),
    ).listen((pos) {
      if (_ultimaPosicion != null && _running) {
        _distanciaMetros += Geolocator.distanceBetween(
          _ultimaPosicion!.latitude,
          _ultimaPosicion!.longitude,
          pos.latitude,
          pos.longitude,
        );
      }
      _ultimaPosicion = pos;
      if (_running) {
        _recorrido.add({
          'seg': _seg,
          'lat': pos.latitude,
          'lng': pos.longitude,
          'altitud': pos.altitude,
        });
      }
    });
  }

  // Distancia recorrida en la sesión, en kilómetros.
  double get _distanciaKm => _distanciaMetros / 1000;

  // Escanea 15s la placa de un pie para conectar desde esta pantalla, sin pasar por VistaBluetooth.
  Future<void> _conectarPie(Pie pie) async {
    if (_estadoConexDe(pie) == _EstadoConexion.buscando ||
        _estadoConexDe(pie) == _EstadoConexion.conectado) {
      return;
    }
    setState(() => _setEstadoConex(pie, _EstadoConexion.buscando));
    final ok = await escanearYConectarPie(pie, timeout: const Duration(seconds: 15));
    if (!mounted) {
      return;
    }
    if (ok) {
      _suscribirNotify(pie);
      _escucharDesconexion(pie);
      setState(() => _setEstadoConex(pie, _EstadoConexion.conectado));
      if (!_running) {
        _iniciarTimer();
      }
    } else {
      setState(() => _setEstadoConex(pie, _EstadoConexion.fallo));
    }
  }

  // Curva en "M": Heel Strike(sube)->Midstance(valle)->Propulsion(2º pico)->Swing(cae a 0); exige varias muestras seguidas para confirmar y filtrar ruido.
  void _actualizarFaseMarcha(double presion, Pie pie) {
    final m = _marcha(pie);
    final direccion = presion > m.ultimaPresion
        ? 1
        : (presion < m.ultimaPresion ? -1 : m.direccion);
    if (direccion == m.direccion) {
      m.muestrasEnDireccion++;
    } else {
      m.direccion = direccion;
      m.muestrasEnDireccion = 1;
    }
    final cambioConfirmado = m.muestrasEnDireccion >= _kMuestrasParaConfirmar;

    switch (m.fase) {
      case 'Heel Strike':
        if (cambioConfirmado && m.direccion == -1) {
          m.fase = 'Midstance'; // primer pico alcanzado, empieza a bajar
        }
        break;
      case 'Midstance':
        if (cambioConfirmado && m.direccion == 1) {
          m.fase = 'Propulsion'; // valle superado, vuelve a subir
        }
        break;
      case 'Propulsion':
        if (presion < kUmbralContacto) {
          m.fase = 'Swing'; // el pie se ha despegado del suelo
        }
        break;
      case 'Swing':
      default:
        if (presion >= kUmbralContacto) {
          m.fase = 'Heel Strike'; // el pie vuelve a tocar el suelo
          _registrarPaso(pie);
        }
        break;
    }
    m.ultimaPresion = presion;
  }

  // Registra un apoyo de talón para pasos/cadencia; descarta del historial los apoyos fuera de la ventana.
  void _registrarPaso(Pie pie) {
    final m = _marcha(pie);
    m.pasos++;
    final ahora = DateTime.now();
    m.tiemposPaso.add(ahora);
    m.tiemposPaso.removeWhere((t) => ahora.difference(t) > _kVentanaCadencia);
  }

  // Pasos totales reales, suma de los apoyos detectados en cada pie.
  int get _pasosTotales => _marchaDer.pasos + _marchaIzq.pasos;

  // Cadencia instantánea (pasos/min) de ambos pies en los últimos _kVentanaCadencia segundos; con <2 apoyos no hay dato suficiente.
  int get _cadencia {
    final tiempos = [..._marchaDer.tiemposPaso, ..._marchaIzq.tiemposPaso]
      ..sort();
    if (tiempos.length < 2) {
      return 0;
    }
    final segundos =
        tiempos.last.difference(tiempos.first).inMilliseconds / 1000;
    if (segundos <= 0) {
      return 0;
    }
    return ((tiempos.length - 1) / segundos * 60).round();
  }

  // Traduce el código interno de fase al texto de pantalla, sin tocar el código usado en comparaciones.
  String _trFase(String fase) {
    switch (fase) {
      case 'Heel Strike':
        return tr('gait_phase_heel_strike');
      case 'Midstance':
        return tr('gait_phase_midstance');
      case 'Propulsion':
        return tr('gait_phase_propulsion');
      default:
        return tr('gait_phase_swing');
    }
  }

  // Color de una fase de marcha, para los chips de estado en la UI.
  Color _colorFase(String fase) {
    switch (fase) {
      case 'Heel Strike':
        return kOrange;
      case 'Midstance':
        return kTeal;
      case 'Propulsion':
        return kRed;
      default:
        return kGray;
    }
  }

  // Fracción de talón (0-1) por fase: Heel Strike=1, Midstance=0.5, Propulsion/Swing=0.
  double _pesoTalon(Pie pie) {
    switch (_marcha(pie).fase) {
      case 'Heel Strike':
        return 1.0;
      case 'Midstance':
        return 0.5;
      default: // Propulsion, Swing
        return 0.0;
    }
  }

  // Fracción de talón por magnitud (vs calibración talón/punta), para calcularStrikeIndex: _pesoTalon en Heel Strike siempre da 100%, esta señal distingue el patrón real.
  double? _wMagTalonDer, _wMagTalonIzq;
  double? _pesoTalonMagnitud(double presion, Pie pie) {
    final calib = calibPie(pie);
    if (calib.adcTalon == null || calib.adcPunta == null) {
      return null;
    }
    final refTalon = adcAPresion(calib.adcTalon!, pie);
    final refPunta = adcAPresion(calib.adcPunta!, pie);
    final distTalon = (presion - refTalon).abs();
    final distPunta = (presion - refPunta).abs();
    final sumaDist = distTalon + distPunta;
    return sumaDist <= 0 ? 0.5 : distPunta / sumaDist;
  }

  // Parsea un paquete BLE, actualiza la presión mostrada y, si la sesión está en marcha, añade la muestra a los datos a guardar.
  void _procesarDatos(List<int> data, Pie pie) {
    if (data.isEmpty) {
      return;
    }
    final raw = utf8.decode(data).trim();
    // ADC crudo (0-4095); el % se calcula con la calibración del usuario, no un rango fijo de firmware.
    final adc = double.tryParse(raw);
    if (adc == null) {
      return;
    }
    final presion = adcAPresion(adc, pie);
    // Un único sensor por pie: se reparte la lectura entre talón/metatarso según la fase (ver _pesoTalon).
    _actualizarFaseMarcha(presion, pie);
    final fase = _marcha(pie).fase;
    final wTalon = _pesoTalon(pie);
    // En Swing _pesoTalon daría el mismo peso que Propulsion; se corta a 0 para no contar ruido como apoyo real.
    final t = fase == 'Swing' ? 0.0 : presion * wTalon;
    final m = fase == 'Swing' ? 0.0 : presion * (1 - wTalon);
    final wMag = _pesoTalonMagnitud(presion, pie);
    if (pie == Pie.derecha) {
      _presionTalonDer = t;
      _presionMetaDer = m;
      _wMagTalonDer = wMag;
    } else {
      _presionTalonIzq = t;
      _presionMetaIzq = m;
      _wMagTalonIzq = wMag;
    }
    // Repintar a 100Hz excede lo que la pantalla refresca; se limita a ~60/seg (16ms), pero cada muestra se sigue guardando.
    final ahora = DateTime.now();
    if (mounted &&
        (_ultimoRefrescoUi == null ||
            ahora.difference(_ultimoRefrescoUi!) >=
                const Duration(milliseconds: 16))) {
      _ultimoRefrescoUi = ahora;
      setState(() {});
    }
    if (_running) {
      _datosSesion.add({
        'seg': _seg,
        'talonIzq': _presionTalonIzq,
        'metaIzq': _presionMetaIzq,
        'talonDer': _presionTalonDer,
        'metaDer': _presionMetaDer,
        'faseIzq': _marchaIzq.fase,
        'faseDer': _marchaDer.fase,
        'wMagTalonIzq': _wMagTalonIzq,
        'wMagTalonDer': _wMagTalonDer,
      });
    }
  }

  // Formatea segundos como mm:ss.
  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  // Libera timers/streams y desconecta las placas gestionadas desde esta pantalla al salir.
  @override
  void dispose() {
    _timerCrono?.cancel();
    _notifySubDer?.cancel();
    _notifySubIzq?.cancel();
    _connSubDer?.cancel();
    _connSubIzq?.cancel();
    _posSub?.cancel();
    if (_connSubDer != null) {
      unawaited(bleDer.device?.disconnect());
    }
    if (_connSubIzq != null) {
      unawaited(bleIzq.device?.disconnect());
    }
    super.dispose();
  }

  // Navega a la pantalla de resumen para revisar y guardar la sesión.
  void _irAResumen() {
    Navigator.push(
        context,
        gogaitRoute(
            builder: (_) => VistaResumen(
                segundos: _seg,
                onFinalizar: () => _timerCrono?.cancel(),
                presionMetaIzq: _presionMetaIzq,
                presionTalonIzq: _presionTalonIzq,
                presionMetaDer: _presionMetaDer,
                presionTalonDer: _presionTalonDer,
                pasos: _pasosTotales,
                distanciaKm: _distanciaKm,
                tipoInicial: widget.tipoActividad,
                datosSesion: List.from(_datosSesion),
                recorrido: List.from(_recorrido))));
  }

  // Al volver atrás: sin sesión en marcha sale directo, con sesión pregunta antes de ir al resumen.
  Future<void> _confirmarFinalizar() async {
    if (!_running) {
      Navigator.pop(context);
      return;
    }
    final finalizar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: kGrayDark)),
        title: Text(tr('finish_activity_title'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        content: Text(tr('finish_activity_msg'),
            style: const TextStyle(color: kGray, fontSize: 14)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('cancel_button'), style: const TextStyle(color: kGray))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('finish_button'),
                  style: const TextStyle(
                      color: kOrange, fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (finalizar == true && mounted) {
      _irAResumen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) {
            return;
          }
          await _confirmarFinalizar();
        },
        child: Scaffold(
          backgroundColor: kBg,
          body: SafeArea(
              child: Column(children: [
            Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(children: [
                          GestureDetector(
                              onTap: _confirmarFinalizar,
                              child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                      color: kCard,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: kGrayDark)),
                                  child: const Icon(Icons.chevron_left,
                                      color: Colors.white, size: 20))),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(tr('live_analysis'),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ]),
                      ),
                      const SizedBox(width: 8),
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                              color: kTeal.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20)),
                          child: Row(children: [
                            const Icon(Icons.bluetooth, color: kTeal, size: 14),
                            const SizedBox(width: 4),
                            Text(
                                _ambasConectadas
                                    ? tr('status_connected')
                                    : _algunaConectada
                                        ? tr('ble_half_connected')
                                        : tr('searching_short'),
                                style: const TextStyle(
                                    color: kTeal,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ])),
                    ])),
            if (!_ambasConectadas)
              Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: GogaitCard(
                      child: Column(children: [
                        for (final pie in Pie.values) ...[
                          if (pie == Pie.izquierda)
                            const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Divider(
                                    color: Color(0xFF374151), height: 1)),
                          Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                    child: Text(
                                        '${pie == Pie.derecha ? tr('insole_right') : tr('insole_left')}: ${_textoEstadoConex(_estadoConexDe(pie))}',
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        style: TextStyle(
                                            color: _estadoConexDe(pie) ==
                                                    _EstadoConexion.buscando
                                                ? kOrange
                                                : _estadoConexDe(pie) ==
                                                        _EstadoConexion
                                                            .conectado
                                                    ? kTeal
                                                    : kGray,
                                            fontSize: 13))),
                                if (_estadoConexDe(pie) !=
                                    _EstadoConexion.buscando)
                                  if (_estadoConexDe(pie) ==
                                      _EstadoConexion.conectado)
                                    const Icon(Icons.check_circle,
                                        color: kTeal, size: 18)
                                  else
                                    GestureDetector(
                                        onTap: () => _conectarPie(pie),
                                        child: Container(
                                            padding: const EdgeInsets
                                                .symmetric(
                                                horizontal: 14, vertical: 6),
                                            decoration: BoxDecoration(
                                                gradient: kGradient,
                                                borderRadius:
                                                    BorderRadius.circular(8)),
                                            child: Text(tr('connect_button'),
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.w600))))
                                else
                                  const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: kOrange)),
                              ]),
                        ],
                      ]))),
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(children: [
                  Text(tr('session_duration'),
                      style: const TextStyle(color: kGray, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(_fmt(_seg),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2)),
                  const SizedBox(height: 10),
                  // Fase + lectura cruda por pie, mismo orden izq/der que el heatmap; solo para comprobar que el sensor mide.
                  Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            for (final pie in _kOrdenPies)
                              Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                      color: _colorFase(_marcha(pie).fase)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(20)),
                                  child: Text(
                                      '${_trFase(_marcha(pie).fase)} · ${_presionActual(pie).round()}%',
                                      style: TextStyle(
                                          color: _colorFase(_marcha(pie).fase),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600))),
                          ])),
                ])),
            Expanded(
                child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(children: [
                      GogaitCard(
                          padding: const EdgeInsets.all(20),
                          child: Column(children: [
                            Text(tr('plantar_pressure'),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15)),
                            const SizedBox(height: 16),
                            Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  FootHeatmapWidget(
                                      data: _leftData,
                                      label: tr('left_foot'),
                                      isLeft: true),
                                  FootHeatmapWidget(
                                      data: _rightData,
                                      label: tr('right_foot'),
                                      isLeft: false),
                                ]),
                            const SizedBox(height: 16),
                            const Divider(color: Color(0xFF374151)),
                            const SizedBox(height: 8),
                            Text(tr('pressure_level'),
                                style: const TextStyle(color: kGray, fontSize: 11)),
                            const SizedBox(height: 6),
                            Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(tr('low_label'),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        style: const TextStyle(
                                            color: kGray, fontSize: 11)),
                                  ),
                                  ...[
                                    0xFFFFE082,
                                    0xFFFFC107,
                                    0xFFFF8A00,
                                    0xFFFF3D57,
                                    0xFFFF0000,
                                    0xFFB026FF
                                  ].map((c) => Container(
                                      width: 24,
                                      height: 8,
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 2),
                                      decoration: BoxDecoration(
                                          color: Color(c),
                                          borderRadius:
                                              BorderRadius.circular(4)))),
                                  const Text(' >100%',
                                      style: TextStyle(
                                          color: kGray, fontSize: 11)),
                                ]),
                          ])),
                      const SizedBox(height: 12),
                      Row(
                          children: [
                        {
                          'label': tr('metric_distance'),
                          'value': '${_distanciaKm.toStringAsFixed(2)} km',
                          'color': kRed,
                          'ultimo': false,
                        },
                        {
                          'label': tr('metric_cadence'),
                          'value': '$_cadencia',
                          'color': kPurple,
                          'ultimo': true,
                          'info': tr('cadence_info'),
                        },
                      ]
                              .map((m) => Expanded(
                                      child: Padding(
                                    padding: EdgeInsets.only(
                                        right: (m['ultimo'] as bool) ? 0 : 8.0),
                                    child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                            color: kCard,
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            border: Border.all(
                                                color: kGrayDark.withValues(
                                                    alpha: 0.5))),
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(children: [
                                                Flexible(
                                                  child: Text(
                                                      m['label'] as String,
                                                      overflow: TextOverflow
                                                          .ellipsis,
                                                      maxLines: 1,
                                                      style: const TextStyle(
                                                          color: kGray,
                                                          fontSize: 11)),
                                                ),
                                                if (m['info'] != null)
                                                  InfoTip(
                                                      titulo:
                                                          m['label'] as String,
                                                      texto: m['info']
                                                          as String),
                                              ]),
                                              const SizedBox(height: 4),
                                              Text(m['value'] as String,
                                                  style: TextStyle(
                                                      color:
                                                          m['color'] as Color,
                                                      fontSize: 17,
                                                      fontWeight:
                                                          FontWeight.w700)),
                                            ])),
                                  )))
                              .toList()),
                    ]))),
            Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(children: [
                  Row(children: [
                    Expanded(
                        child: GestureDetector(
                            onTap: () {
                              if (!mounted) {
                                return;
                              }
                              setState(() => _paused = !_paused);
                              if (_paused) {
                                _timerCrono?.cancel();
                              } else if (_running) {
                                _timerCrono = Timer.periodic(
                                    const Duration(seconds: 1), (_) {
                                  if (mounted) {
                                    setState(() => _seg++);
                                  }
                                });
                              }
                            },
                            child: Container(
                                height: 52,
                                decoration: BoxDecoration(
                                    color: kCard,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: kGrayDark)),
                                child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                          _paused
                                              ? Icons.play_arrow
                                              : Icons.pause,
                                          color: Colors.white,
                                          size: 20),
                                      const SizedBox(width: 6),
                                      Text(_paused ? tr('resume_button') : tr('pause_button'),
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600)),
                                    ])))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: GestureDetector(
                            onTap: !_running
                                ? (_algunaConectada ? () => _iniciarTimer() : null)
                                : _irAResumen,
                            child: Opacity(
                                opacity:
                                    (!_running && !_algunaConectada) ? 0.4 : 1.0,
                                child: Container(
                                    height: 52,
                                    decoration: BoxDecoration(
                                        gradient: kGradient,
                                        borderRadius:
                                            BorderRadius.circular(16)),
                                    child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                              _running
                                                  ? Icons.stop
                                                  : Icons.play_arrow,
                                              color: Colors.white,
                                              size: 20),
                                          const SizedBox(width: 6),
                                          Text(_running ? tr('finish_button') : tr('start_button'),
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600)),
                                        ]))))),
                  ]),
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                            shape: BoxShape.circle, color: kRed)),
                    const SizedBox(width: 6),
                    Text(tr('recording_in_progress'),
                        style: const TextStyle(color: kGray, fontSize: 13)),
                  ]),
                ])),
          ])),
        ));
  }
}

// ---- SESSION SUMMARY SCREEN ----
// Pantalla tras terminar la actividad: elegir tipo, título/notas y guardar la sesión en el historial.
class VistaResumen extends StatefulWidget {
  final int segundos;
  final VoidCallback onFinalizar;
  final double presionMetaIzq, presionTalonIzq, presionMetaDer, presionTalonDer;
  final int pasos;
  final double distanciaKm;
  final String tipoInicial;
  final List<Map<String, dynamic>> datosSesion;
  final List<Map<String, dynamic>> recorrido;
  const VistaResumen(
      {super.key,
      required this.segundos,
      required this.onFinalizar,
      required this.presionMetaIzq,
      required this.presionTalonIzq,
      required this.presionMetaDer,
      required this.presionTalonDer,
      required this.pasos,
      required this.distanciaKm,
      this.tipoInicial = 'running',
      required this.datosSesion,
      this.recorrido = const []});
  @override
  State<VistaResumen> createState() => _VistaResumenState();
}

class _VistaResumenState extends State<VistaResumen> with IdiomaListenerMixin {
  late String _tipo;
  final _titulo = TextEditingController();
  final _notas = TextEditingController();
  String _footFilter = 'both';
  // Último título autogenerado (hora+tipo); si el usuario lo cambia a mano, se deja de tocar aunque cambie el tipo (ver _tituloPorDefecto).
  String? _ultimoTituloAuto;

  @override
  void initState() {
    super.initState();
    // Tipo ya elegido antes de calibrar (VistaSeleccionActividad); aquí solo se prellena, se puede cambiar desde el selector.
    _tipo = widget.tipoInicial;
    _ultimoTituloAuto = _tituloPorDefecto(_tipo);
    _titulo.text = _ultimoTituloAuto!;
  }

  // "Morning Run", "Afternoon Walk"... según la hora actual y el tipo de actividad.
  String _tituloPorDefecto(String tipo) {
    final hora = DateTime.now().hour;
    final momento = hora < 5
        ? tr('time_night')
        : hora < 12
            ? tr('time_morning')
            : hora < 17
                ? tr('time_afternoon')
                : hora < 21
                    ? tr('time_evening')
                    : tr('time_night');
    final actividad = tipo == 'walking'
        ? tr('activity_walk')
        : tipo == 'trail'
            ? tr('trail_run')
            : tr('activity_run');
    return '$momento $actividad';
  }

  // Media de una columna sobre todas las muestras, no la última lectura (que podía caer sin apoyo).
  double _mediaMuestras(String clave, double valorSiVacio) {
    if (widget.datosSesion.isEmpty) {
      return valorSiVacio;
    }
    final valores =
        widget.datosSesion.map((d) => (d[clave] as num).toDouble());
    return valores.reduce((a, b) => a + b) / widget.datosSesion.length;
  }

  void _guardar() {
    widget.onFinalizar();
    final now = DateTime.now();
    final presionMetaMedia =
        _mediaMuestras('metaDer', widget.presionMetaDer);
    final presionTalonMedia =
        _mediaMuestras('talonDer', widget.presionTalonDer);
    final presionMetaIzqMedia =
        _mediaMuestras('metaIzq', widget.presionMetaIzq);
    final presionTalonIzqMedia =
        _mediaMuestras('talonIzq', widget.presionTalonIzq);
    final impacto = calcularImpacto(widget.datosSesion, Pie.derecha);
    final impactoIzq = calcularImpacto(widget.datosSesion, Pie.izquierda);
    historial.add(SesionActividad(
      id: now.toString(),
      titulo: _titulo.text,
      descripcion: _notas.text,
      tipo: _tipo,
      fecha: '${now.day}/${now.month}/${now.year}',
      hora: '${now.hour}:${now.minute.toString().padLeft(2, '0')}',
      duracion: '${widget.segundos ~/ 60}min ${widget.segundos % 60}s',
      // Media de toda la sesión, no la última lectura instantánea.
      presionMeta: presionMetaMedia,
      presionTalon: presionTalonMedia,
      presionMetaIzq: presionMetaIzqMedia,
      presionTalonIzq: presionTalonIzqMedia,
      pasos: widget.pasos,
      // Cadencia media de toda la sesión (no la instantánea en vivo).
      cadencia: widget.segundos > 0 ? widget.pasos / (widget.segundos / 60) : 0,
      distanciaKm: widget.distanciaKm,
      balance: calcularBalance(widget.datosSesion),
      impacto: impacto,
      impactoIzq: impactoIzq,
      // Media de ambos pies, no solo derecho (ver impactoMedioPeriodo): impactoKg es cifra general de Impact.
      impactoKg: impactoAKg((impacto + impactoIzq) / 2, usuarioActual?.peso ?? 0),
      zancadaRatio: ratioZancada(widget.distanciaKm, widget.pasos,
              usuarioActual?.altura ?? 0, _tipo) ??
          0,
      strikeIndexDer: calcularStrikeIndex(widget.datosSesion, Pie.derecha),
      strikeIndexIzq: calcularStrikeIndex(widget.datosSesion, Pie.izquierda),
      tieneBalance: tieneDatosPieIzquierdo(widget.datosSesion),
      tieneFatiga: tieneDatosFatiga(widget.datosSesion),
      tieneStrikeDer: tieneDatosStrikeIndex(widget.datosSesion, Pie.derecha),
      tieneStrikeIzq: tieneDatosStrikeIndex(widget.datosSesion, Pie.izquierda),
      tieneImpacto: widget.datosSesion.isNotEmpty,
      fatiga: calcularFatiga(widget.datosSesion),
      tramosFatiga: tramosFatiga(widget.datosSesion),
      datosSesion: List.from(widget.datosSesion),
      recorrido: List.from(widget.recorrido),
      // Foto de la calibración activa al guardar, fija a esta sesión aunque se recalibre después (ver SesionActividad).
      adcReposoDer: calibDer.adcReposo,
      adcCargaDer: calibDer.adcCarga,
      adcTalonDer: calibDer.adcTalon,
      adcPuntaDer: calibDer.adcPunta,
      adcReposoIzq: calibIzq.adcReposo,
      adcCargaIzq: calibIzq.adcCarga,
      adcTalonIzq: calibIzq.adcTalon,
      adcPuntaIzq: calibIzq.adcPunta,
    ));
    guardarHistorial();
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final durStr =
        '${(widget.segundos ~/ 60).toString().padLeft(2, '0')}:${(widget.segundos % 60).toString().padLeft(2, '0')}';
    final steps = widget.pasos;
    final km = widget.distanciaKm.toStringAsFixed(2);

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
          child: Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
              GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          color: kCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kGrayDark)),
                      child:
                          const Icon(Icons.chevron_left, color: Colors.white))),
              Expanded(
                  child: Text(tr('session_summary'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600))),
              const SizedBox(width: 36),
            ])),

        Expanded(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('activity_type'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15)),
                      const SizedBox(height: 10),
                      Row(
                          children: [
                        {'type': 'walking', 'icon': Icons.directions_walk},
                        {
                          'type': 'running',
                          'icon': Icons.directions_run_outlined
                        },
                        {'type': 'trail', 'icon': Icons.landscape_outlined},
                      ]
                              .map((a) => Expanded(
                                      child: GestureDetector(
                                    onTap: () => setState(() {
                                      _tipo = a['type'] as String;
                                      // Solo actualiza el título si sigue siendo el autogenerado.
                                      if (_titulo.text == _ultimoTituloAuto) {
                                        _ultimoTituloAuto =
                                            _tituloPorDefecto(_tipo);
                                        _titulo.text = _ultimoTituloAuto!;
                                      }
                                    }),
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      height: 60,
                                      decoration: BoxDecoration(
                                        gradient: _tipo == a['type']
                                            ? kGradient
                                            : null,
                                        color:
                                            _tipo == a['type'] ? null : kCard,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                            color: _tipo == a['type']
                                                ? Colors.transparent
                                                : kGrayDark),
                                      ),
                                      child: Icon(a['icon'] as IconData,
                                          color: _tipo == a['type']
                                              ? Colors.white
                                              : kOrange,
                                          size: 28),
                                    ),
                                  )))
                              .toList()),
                      const SizedBox(height: 16),

                      Text(tr('activity_title'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15)),
                      const SizedBox(height: 10),
                      GogaitInput(
                          label: '', hint: tr('activity_title_hint'), controller: _titulo),
                      const SizedBox(height: 16),

                      Text(tr('notes_optional'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15)),
                      const SizedBox(height: 10),
                      GogaitInput(
                          label: '',
                          hint: tr('notes_hint'),
                          controller: _notas,
                          maxLines: 3),
                      const SizedBox(height: 16),

                      GogaitCard(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(tr('session_performance'),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15)),
                                const SizedBox(height: 16),
                                Row(
                                    children: [
                                  {'v': 'both', 'l': tr('both_feet')},
                                  {'v': 'left', 'l': tr('left_foot')},
                                  {'v': 'right', 'l': tr('right_foot')},
                                ]
                                        .map((f) => Expanded(
                                                child: GestureDetector(
                                              onTap: () => setState(() =>
                                                  _footFilter =
                                                      f['v'] as String),
                                              child: Container(
                                                margin: const EdgeInsets.only(
                                                    right: 4),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: _footFilter == f['v']
                                                      ? kOrange.withValues(
                                                          alpha: 0.15)
                                                      : Colors.transparent,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  border: Border.all(
                                                      color:
                                                          _footFilter == f['v']
                                                              ? kOrange
                                                              : kGrayDark),
                                                ),
                                                alignment: Alignment.center,
                                                child: Text(f['l'] as String,
                                                    style: TextStyle(
                                                        color: _footFilter ==
                                                                f['v']
                                                            ? kOrange
                                                            : kGray,
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w500)),
                                              ),
                                            )))
                                        .toList()),
                                const SizedBox(height: 24),
                                Builder(builder: (context) {
                                  // Balance requiere señal real del pie izq (tieneDatosPieIzquierdo); si no, N/A en vez de un 50 fingido.
                                  // No usa _footFilter: Balance ya compara ambos pies. Se muestra como % de desequilibrio (0=simétrico), no el balance crudo (50=simétrico).
                                  final tieneIzq = tieneDatosPieIzquierdo(
                                      widget.datosSesion);
                                  final balanceVal = tieneIzq
                                      ? ((calcularBalance(widget.datosSesion) -
                                                  50)
                                              .abs() *
                                          2)
                                          .round()
                                      : null;
                                  // Impact sí varía con _footFilter: el pico de presión por contacto puede ser distinto en cada pie.
                                  final impactoPct = widget.datosSesion.isEmpty
                                      ? null
                                      : _footFilter == 'left'
                                          ? (tieneIzq
                                              ? calcularImpacto(
                                                  widget.datosSesion,
                                                  Pie.izquierda)
                                              : null)
                                          : _footFilter == 'right'
                                              ? calcularImpacto(
                                                  widget.datosSesion,
                                                  Pie.derecha)
                                              : (tieneIzq
                                                  ? ((calcularImpacto(
                                                              widget
                                                                  .datosSesion,
                                                              Pie.derecha) +
                                                          calcularImpacto(
                                                              widget
                                                                  .datosSesion,
                                                              Pie.izquierda)) /
                                                      2)
                                                  : calcularImpacto(
                                                      widget.datosSesion,
                                                      Pie.derecha));
                                  final impactoVal = impactoPct?.round();
                                  // Igual que en Detalle de actividad: con peso registrado se muestra en kg en vez de %; el anillo sigue lleno según el %.
                                  final peso = usuarioActual?.peso ?? 0;
                                  final impactoKgVal = (impactoPct != null &&
                                          peso > 0)
                                      ? '${impactoAKg(impactoPct, peso).round()} kg'
                                      : null;
                                  return Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        _CircProgress(
                                            value: balanceVal,
                                            color: kTeal,
                                            label: tr('metric_balance'),
                                            info: tr('balance_info')),
                                        _CircProgress(
                                            value: impactoVal,
                                            etiquetaNumero: impactoKgVal,
                                            color: kOrange,
                                            label: tr('metric_impact'),
                                            info: tr('impact_info')),
                                      ]);
                                }),
                              ])),
                      const SizedBox(height: 16),

                      Row(
                          children: [
                        {
                          'label': tr('duration_label'),
                          'value': durStr,
                          'color': kPurple,
                          'ultimo': false,
                        },
                        {'label': tr('steps_label'), 'value': '$steps', 'color': kRed, 'ultimo': false},
                        {
                          'label': tr('metric_distance'),
                          'value': '$km km',
                          'color': kTeal,
                          'ultimo': true,
                        },
                      ]
                              .map((s) => Expanded(
                                      child: Padding(
                                    padding: EdgeInsets.only(
                                        right: (s['ultimo'] as bool) ? 0 : 8.0),
                                    child: Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                            color: kCard,
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            border: Border.all(
                                                color: kGrayDark.withValues(
                                                    alpha: 0.5))),
                                        child: Column(children: [
                                          Text(s['label'] as String,
                                              style: const TextStyle(
                                                  color: kGray, fontSize: 11)),
                                          const SizedBox(height: 4),
                                          Text(s['value'] as String,
                                              style: TextStyle(
                                                  color: s['color'] as Color,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700)),
                                        ])),
                                  )))
                              .toList()),
                      const SizedBox(height: 20),

                      GestureDetector(
                        onTap: _guardar,
                        child: Container(
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                                gradient: kGradient,
                                borderRadius: BorderRadius.circular(16)),
                            child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.save_outlined,
                                      color: Colors.white, size: 20),
                                  const SizedBox(width: 8),
                                  Text(tr('save_session'),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16)),
                                ])),
                      ),
                    ]))),
      ])),
    );
  }
}

// Anillo de progreso circular con el valor en el centro (Balance, Impact...).
// value a null: no se puede calcular esa métrica, muestra "N/A" y anillo gris en vez de un número inventado.
class _CircProgress extends StatelessWidget {
  final int? value;
  final Color color;
  final String label;
  final String? info;
  // Sustituye el "X%" central por este texto cuando se conoce (p.ej. "X kg"); el anillo sigue lleno según value.
  final String? etiquetaNumero;
  const _CircProgress(
      {required this.value,
      required this.color,
      required this.label,
      this.info,
      this.etiquetaNumero});
  @override
  Widget build(BuildContext context) {
    final conocido = value != null;
    return Column(children: [
      SizedBox(
          width: 95,
          height: 95,
          // Anima de 0 al valor real cada vez que aparece, sin recortar para que el número pueda superar 100.
          child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: conocido ? value!.toDouble() : 0),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, animado, __) => Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                        width: 95,
                        height: 95,
                        child: CircularProgressIndicator(
                            // El anillo tope a 100%; el texto de abajo sí muestra el valor real.
                            value: conocido ? (animado / 100).clamp(0.0, 1.0) : 0,
                            strokeWidth: 9,
                            backgroundColor: kGrayDark,
                            valueColor: AlwaysStoppedAnimation(
                                conocido ? color : kGray))),
                    Text(
                        conocido
                            ? (etiquetaNumero ?? '${animado.round()}%')
                            : 'N/A',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: conocido ? 22 : 16,
                            fontWeight: FontWeight.w700)),
                  ])),
      ),
      const SizedBox(height: 8),
      Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        if (info != null) InfoTip(titulo: label, texto: info!),
      ]),
    ]);
  }
}

// ---- HISTORY SCREEN ----
// Historial de actividades, filtrable por tipo (all/walking/running/trail).
class VistaHistorico extends StatefulWidget {
  const VistaHistorico({super.key});
  @override
  State<VistaHistorico> createState() => _VistaHistoricoState();
}

class _VistaHistoricoState extends State<VistaHistorico> with IdiomaListenerMixin {
  String _filter = 'all';

  // Icono representativo según el tipo de actividad.
  IconData _iconForType(String t) {
    switch (t) {
      case 'running':
        return Icons.directions_run;
      case 'trail':
        return Icons.terrain;
      default:
        return Icons.directions_walk;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filter == 'all'
        ? historial
        : historial.where((s) => s.tipo == _filter).toList();
    // s.duracion es "12min 34s" (ver VistaResumen._guardar); se reconstruyen minutos+segundos completos, no solo la parte antes de 'min'.
    final totalMin = filtered.fold<double>(0, (sum, s) {
      final m = RegExp(r'(\d+)min\s*(\d+)s').firstMatch(s.duracion);
      if (m == null) {
        return sum;
      }
      return sum + int.parse(m.group(1)!) + int.parse(m.group(2)!) / 60;
    });
    final totalKm = filtered.fold<double>(0, (sum, s) => sum + s.distanciaKm);

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
          child: Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
              GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          color: kCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kGrayDark)),
                      child: const Icon(Icons.chevron_left,
                          color: Colors.white, size: 20))),
              Expanded(
                  child: Text(tr('activity_history'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600))),
              const SizedBox(width: 36),
            ])),
        Expanded(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          kOrange.withValues(alpha: 0.12),
                          kRed.withValues(alpha: 0.12),
                          kYellow.withValues(alpha: 0.12)
                        ]),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: kGrayDark.withValues(alpha: 0.5))),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatItem(
                              icon: Icons.access_time,
                              color: kPurple,
                              value: '${(totalMin / 60).toStringAsFixed(1)}h',
                              label: tr('hours_label')),
                          _StatItem(
                              icon: Icons.directions_walk,
                              color: kRed,
                              value: '${filtered.length}',
                              label: tr('sessions_label')),
                          _StatItem(
                              icon: Icons.location_on_outlined,
                              color: kOrange,
                              value: '${totalKm.toStringAsFixed(1)}km',
                              label: tr('metric_distance')),
                        ]),
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        _FilterBtn(
                            label: tr('filter_all'),
                            value: 'all',
                            current: _filter,
                            onTap: (v) => setState(() => _filter = v)),
                        _FilterBtn(
                            label: tr('filter_walking'),
                            value: 'walking',
                            current: _filter,
                            onTap: (v) => setState(() => _filter = v),
                            icon: Icons.directions_walk),
                        _FilterBtn(
                            label: tr('filter_running'),
                            value: 'running',
                            current: _filter,
                            onTap: (v) => setState(() => _filter = v),
                            icon: Icons.directions_run),
                        _FilterBtn(
                            label: tr('filter_trail'),
                            value: 'trail',
                            current: _filter,
                            onTap: (v) => setState(() => _filter = v),
                            icon: Icons.terrain),
                      ])),
                  const SizedBox(height: 16),
                  if (filtered.isEmpty)
                    Padding(
                        padding: const EdgeInsets.all(40),
                        child: Text(tr('no_activities_found'),
                            style: const TextStyle(color: kGray),
                            textAlign: TextAlign.center)),
                  ...filtered.reversed.map((s) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GestureDetector(
                        onTap: () async {
                          await Navigator.push(
                              context,
                              gogaitRoute(
                                  builder: (_) =>
                                      VistaDetalleHistorico(sesion: s)));
                          if (mounted) {
                            setState(() {});
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              color: kCard,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: kGrayDark.withValues(alpha: 0.5))),
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                        gradient: LinearGradient(colors: [
                                          kOrange.withValues(alpha: 0.2),
                                          kRed.withValues(alpha: 0.2)
                                        ]),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                            color: kOrange.withValues(
                                                alpha: 0.3))),
                                    child: Icon(_iconForType(s.tipo),
                                        color: kOrange, size: 28)),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Flexible(
                                              child: Text(s.titulo,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 15)),
                                            ),
                                            const SizedBox(width: 8),
                                            const Icon(Icons.chevron_right,
                                                color: kGray, size: 18),
                                          ]),
                                      const SizedBox(height: 2),
                                      Text(
                                          _formatFechaSesion(s, separador: '·'),
                                          style: const TextStyle(
                                              color: kGray, fontSize: 12)),
                                      const SizedBox(height: 8),
                                      Row(children: [
                                        const Icon(Icons.access_time,
                                            color: kGray, size: 14),
                                        const SizedBox(width: 4),
                                        Text(s.duracion,
                                            style: const TextStyle(
                                                color: kGray, fontSize: 12)),
                                        const SizedBox(width: 16),
                                        const Icon(Icons.location_on_outlined,
                                            color: kGray, size: 14),
                                        const SizedBox(width: 4),
                                        Text(
                                            '${s.distanciaKm.toStringAsFixed(1)} km',
                                            style: const TextStyle(
                                                color: kGray, fontSize: 12)),
                                      ]),
                                    ])),
                              ]),
                        ),
                      ),
                    );
                  }),
                ]))),
      ])),
    );
  }
}

// Icono + valor + etiqueta en columna (resumen de Horas/Sesiones/Distancia).
class _StatItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value, label;
  const _StatItem(
      {required this.icon,
      required this.color,
      required this.value,
      required this.label});
  @override
  Widget build(BuildContext context) => Column(children: [
        Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                shape: BoxShape.circle, color: color.withValues(alpha: 0.15)),
            child: Icon(icon, color: color, size: 22)),
        const SizedBox(height: 6),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
        Text(label, style: const TextStyle(color: kGray, fontSize: 11)),
      ]);
}

// Botón-pastilla de filtro (All/Walking/Running/Trail); se resalta si está seleccionado.
class _FilterBtn extends StatelessWidget {
  final String label, value, current;
  final void Function(String) onTap;
  final IconData? icon;
  const _FilterBtn(
      {required this.label,
      required this.value,
      required this.current,
      required this.onTap,
      this.icon});
  @override
  Widget build(BuildContext context) {
    final sel = value == current;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: sel ? kGradient : null,
          color: sel ? null : kCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? Colors.transparent : kGrayDark),
        ),
        child: Row(children: [
          if (icon != null) ...[
            Icon(icon, color: sel ? Colors.white : kOrange, size: 16),
            const SizedBox(width: 4)
          ],
          Text(label,
              style: TextStyle(
                  color: sel ? Colors.white : kGray,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}

// ---- EXPORT METRICS SCREEN ----
// Gráficas de Balance/Impact/Cadence por periodo; periodoMetricasSeleccionado se comparte con Home.
class VistaExportMetrics extends StatefulWidget {
  const VistaExportMetrics({super.key});
  @override
  State<VistaExportMetrics> createState() => _VistaExportMetricsState();
}

class _VistaExportMetricsState extends State<VistaExportMetrics> with IdiomaListenerMixin {
  List<Map<String, String>> get _periods => [
    {'value': 'week', 'label': tr('period_week')},
    {'value': 'month', 'label': tr('period_month')},
    {'value': 'year', 'label': tr('period_year')},
    {'value': 'all', 'label': tr('period_all_time')},
  ];

  // Agrupa sesiones por periodo (semana->día, mes->semana, año/todo->mes) para no amontonar puntos con 1-2 sesiones/semana; Balance/Impact usan las mismas fórmulas que Home.
  List<Map<String, dynamic>> _agruparSesiones(List<SesionActividad> sesiones,
      String Function(DateTime fecha) claveDe,
      String Function(DateTime fecha) etiquetaDe) {
    // LinkedHashMap implícito: como 'sesiones' llega ordenada ascendente, la etiqueta de cada grupo queda la de su sesión más reciente y el orden de inserción es cronológico.
    final grupos = <String, List<SesionActividad>>{};
    final etiquetas = <String, String>{};
    for (final s in sesiones) {
      final fecha = DateTime.tryParse(s.id);
      final clave = fecha == null ? 'sf_${s.id}' : claveDe(fecha);
      grupos.putIfAbsent(clave, () => []).add(s);
      etiquetas[clave] = fecha == null ? s.fecha : etiquetaDe(fecha);
    }
    return grupos.entries.map((e) {
      final lista = e.value;
      // Igual que balanceMedioPeriodo/impactoMedioPeriodo: solo cuentan sesiones con dato real, para no arrastrar el promedio hacia 50/0; si ninguna lo tiene, cae al grupo completo (evita dividir por lista vacía).
      final conBalance = lista.where((s) => s.tieneBalance).toList();
      final baseBalance = conBalance.isEmpty ? lista : conBalance;
      final balance = baseBalance
              .map((s) => (s.balance - 50).abs() * 2)
              .reduce((a, b) => a + b) /
          baseBalance.length;
      final conImpacto = lista.where((s) => s.tieneImpacto).toList();
      final baseImpacto = conImpacto.isEmpty ? lista : conImpacto;
      final impact = baseImpacto
              .map((s) => (s.impacto + s.impactoIzq) / 2)
              .reduce((a, b) => a + b) /
          baseImpacto.length;
      final cadence =
          lista.map((s) => s.cadencia).reduce((a, b) => a + b) /
              lista.length;
      return {
        'date': etiquetas[e.key],
        'balance': balance.round(),
        'impact': impact.round(),
        'cadence': cadence.round(),
      };
    }).toList();
  }

  String _claveDia(DateTime f) => '${f.year}-${f.month}-${f.day}';
  // Nombre del día (Lun, Mar...) en vez de "16/9": sin ambigüedad y más corto en una ventana de 7 días.
  String _etiquetaDia(DateTime f) => tr('weekday_${f.weekday}');

  // Semana de calendario lunes-domingo (weekday 1=lunes, 7=domingo), no ventana móvil de 7 días.
  DateTime _lunesDeLaSemana(DateTime f) {
    final soloFecha = DateTime(f.year, f.month, f.day);
    return soloFecha.subtract(Duration(days: soloFecha.weekday - 1));
  }

  String _claveSemana(DateTime f) {
    final lunes = _lunesDeLaSemana(f);
    return '${lunes.year}-${lunes.month}-${lunes.day}';
  }

  String _claveMes(DateTime f) => '${f.year}-${f.month}';
  String _etiquetaMes(DateTime f) {
    final nombre = tr('month_${f.month}');
    final abrev = nombre.substring(0, nombre.length < 3 ? nombre.length : 3);
    return f.year == DateTime.now().year ? abrev : '$abrev ${f.year % 100}';
  }

  // A diferencia de _agruparSesiones, la etiqueta ("Sem 1", "Sem 2"...) sale del orden de aparición, no de la fecha: el rango "9/9–15/9" liaba más que ayudaba.
  List<Map<String, dynamic>> _agruparPorSemana(List<SesionActividad> sesiones) {
    final grupos = <String, List<SesionActividad>>{};
    for (final s in sesiones) {
      final fecha = DateTime.tryParse(s.id);
      final clave = fecha == null ? 'sf_${s.id}' : _claveSemana(fecha);
      grupos.putIfAbsent(clave, () => []).add(s);
    }
    final etiquetaSemana = tr('week_label_short');
    var indice = 0;
    return grupos.entries.map((e) {
      indice++;
      final lista = e.value;
      // Mismo criterio que _agruparSesiones: solo promediar sesiones con dato real de balance/impacto.
      final conBalance = lista.where((s) => s.tieneBalance).toList();
      final baseBalance = conBalance.isEmpty ? lista : conBalance;
      final balance = baseBalance
              .map((s) => (s.balance - 50).abs() * 2)
              .reduce((a, b) => a + b) /
          baseBalance.length;
      final conImpacto = lista.where((s) => s.tieneImpacto).toList();
      final baseImpacto = conImpacto.isEmpty ? lista : conImpacto;
      final impact = baseImpacto
              .map((s) => (s.impacto + s.impactoIzq) / 2)
              .reduce((a, b) => a + b) /
          baseImpacto.length;
      final cadence =
          lista.map((s) => s.cadencia).reduce((a, b) => a + b) /
              lista.length;
      return {
        'date': '$etiquetaSemana $indice',
        'balance': balance.round(),
        'impact': impact.round(),
        'cadence': cadence.round(),
      };
    }).toList();
  }

  List<Map<String, dynamic>> get _data {
    final sesiones = sesionesEnPeriodo(periodoMetricasSeleccionado);
    switch (periodoMetricasSeleccionado) {
      case 'week':
        return _agruparSesiones(sesiones, _claveDia, _etiquetaDia);
      case 'month':
        return _agruparPorSemana(sesiones);
      default: // 'year' y 'all': una media por mes.
        return _agruparSesiones(sesiones, _claveMes, _etiquetaMes);
    }
  }

  // A diferencia de _data (agrupada), el CSV exporta el detalle real sin promediar, para analizar fuera con el dato crudo.
  List<Map<String, dynamic>> get _datosCsvCrudos =>
      sesionesEnPeriodo(periodoMetricasSeleccionado).map((s) {
        final fecha = DateTime.tryParse(s.id);
        return {
          'date': fecha == null
              ? s.fecha
              : '${fecha.day}/${fecha.month}/${fecha.year}',
          // 'NA' (no un 50/0 que parezca dato real) si la sesión nunca tuvo pie izquierdo o muestras crudas.
          'balance': s.tieneBalance
              ? ((s.balance - 50).abs() * 2).round().toString()
              : 'NA',
          'impact': s.tieneImpacto
              ? ((s.impacto + s.impactoIzq) / 2).round().toString()
              : 'NA',
          'cadence': s.cadencia.round().toString(),
        };
      }).toList();

  // Genera el CSV del periodo seleccionado y abre el diálogo nativo de compartir/guardar.
  Future<void> _exportarCsv() async {
    final buffer = StringBuffer();
    buffer.writeln('date,balance,impact,cadence');
    for (final d in _datosCsvCrudos) {
      buffer.writeln(
          '${d['date']},${d['balance']},${d['impact']},${d['cadence']}');
    }
    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/gogait_metrics_$periodoMetricasSeleccionado.csv');
    await file.writeAsString(buffer.toString());
    if (!mounted) {
      return;
    }
    await Share.shareXFiles([XFile(file.path)],
        text: 'GOGAIT metrics ($periodoMetricasSeleccionado)');
  }

  // Construye la tarjeta con la gráfica de una métrica (balance/impact/cadence).
  Widget _buildChart(String label, String key, Color color,
      {String? infoTexto}) {
    final dataValues = _data.map((d) => (d[key] as int).toDouble()).toList();
    final dataLabels = _data.map((d) => d['date'] as String).toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kGrayDark.withValues(alpha: 0.5))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15)),
          ),
          if (infoTexto != null) InfoTip(titulo: label, texto: infoTexto),
        ]),
        const SizedBox(height: 16),
        SizedBox(
            height: 160,
            child: _InteractiveChart(
                data: dataValues,
                labels: dataLabels,
                color: color,
                metricLabel: label)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Mismas funciones que Home, para no mostrar un número distinto bajo la misma etiqueta.
    final balancePeriodo = balanceMedioPeriodo(periodoMetricasSeleccionado);
    final impactoPeriodo = impactoMedioPeriodo(periodoMetricasSeleccionado);
    final avgBalance = balancePeriodo?.round();
    final avgImpact = impactoPeriodo?.round();
    // Media real de todas las sesiones del periodo (no de los puntos agrupados de _data), igual que balancePeriodo/impactoPeriodo.
    final avgCadence =
        cadenciaMediaPeriodo(periodoMetricasSeleccionado).round();

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
          child: Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
              GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          color: kCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kGrayDark)),
                      child: const Icon(Icons.chevron_left,
                          color: Colors.white, size: 20))),
              Expanded(
                  child: Text(tr('export_metrics_title'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600))),
              const SizedBox(width: 36),
            ])),
        Expanded(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  Row(children: [
                    const Icon(Icons.calendar_today_outlined, color: kGray, size: 16),
                    const SizedBox(width: 8),
                    Text(tr('time_period'),
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 12),
                  Row(
                      children: _periods
                          .map((p) => Expanded(
                                  child: GestureDetector(
                                onTap: () => setState(() =>
                                    periodoMetricasSeleccionado =
                                        p['value']!),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    gradient: periodoMetricasSeleccionado ==
                                            p['value']
                                        ? kGradient
                                        : null,
                                    color: periodoMetricasSeleccionado ==
                                            p['value']
                                        ? null
                                        : kCard,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: periodoMetricasSeleccionado ==
                                                p['value']
                                            ? Colors.transparent
                                            : kGrayDark),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(p['label']!,
                                      style: TextStyle(
                                          color: periodoMetricasSeleccionado ==
                                                  p['value']
                                              ? Colors.white
                                              : kGray,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500)),
                                ),
                              )))
                          .toList()),
                  const SizedBox(height: 20),

                  Row(
                      children: [
                    {
                      // Quick Metrics es la única pantalla donde el número se colorea por umbral; en el resto (Home, Resumen, Detalle) queda fijo.
                      'label': tr('metric_balance'),
                      'value': avgBalance == null ? 'N/A' : '$avgBalance%',
                      'color': balancePeriodo == null
                          ? kGray
                          : colorDesequilibrio(balancePeriodo),
                      'ultimo': false,
                    },
                    {
                      'label': tr('metric_impact'),
                      'value': avgImpact == null ? 'N/A' : '$avgImpact%',
                      'color': impactoPeriodo == null
                          ? kGray
                          : colorImpacto(impactoPeriodo),
                      'ultimo': false,
                    },
                    {
                      'label': tr('metric_cadence'),
                      'value': '$avgCadence spm',
                      'color': kPurple,
                      'ultimo': true,
                    },
                  ]
                          .map((m) => Expanded(
                                  child: Padding(
                                padding: EdgeInsets.only(
                                    right: (m['ultimo'] as bool) ? 0 : 8.0),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                      color: kCard,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                          color: kGrayDark.withValues(
                                              alpha: 0.5))),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(m['label'] as String,
                                            style: const TextStyle(
                                                color: kGray, fontSize: 11)),
                                        const SizedBox(height: 4),
                                        Text(m['value'] as String,
                                            style: TextStyle(
                                                color: m['color'] as Color,
                                                fontSize: 20,
                                                fontWeight: FontWeight.w700)),
                                      ]),
                                ),
                              )))
                          .toList()),
                  const SizedBox(height: 16),

                  // Mismo color que la tarjeta resumen, según la media del periodo (colorDesequilibrio/colorImpacto).
                  _buildChart(
                      tr('metric_balance'),
                      'balance',
                      balancePeriodo == null
                          ? kGray
                          : colorDesequilibrio(balancePeriodo),
                      infoTexto: tr('balance_info')),
                  const SizedBox(height: 12),
                  _buildChart(
                      tr('metric_impact'),
                      'impact',
                      impactoPeriodo == null
                          ? kGray
                          : colorImpacto(impactoPeriodo),
                      infoTexto: tr('impact_info')),
                  const SizedBox(height: 12),
                  _buildChart(tr('metric_cadence'), 'cadence', kPurple,
                      infoTexto: tr('cadence_info')),
                  const SizedBox(height: 20),

                  GestureDetector(
                    onTap: _exportarCsv,
                    child: Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [Color(0xFF00D9C0), Color(0xFF00E6A8)]),
                            borderRadius: BorderRadius.circular(16)),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.download_outlined,
                                  color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Text(tr('export_to_csv'),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16)),
                            ])),
                  ),
                  const SizedBox(height: 8),
                  Text(tr('export_period_note'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: kGray, fontSize: 12)),
                ]))),
      ])),
    );
  }
}

// Gráfica de línea táctil: al tocar, resalta el punto más cercano y muestra su tooltip.
class _InteractiveChart extends StatefulWidget {
  final List<double> data;
  final List<String> labels;
  final Color color;
  final String metricLabel;
  const _InteractiveChart(
      {required this.data,
      required this.labels,
      required this.color,
      required this.metricLabel});
  @override
  State<_InteractiveChart> createState() => _InteractiveChartState();
}

class _InteractiveChartState extends State<_InteractiveChart>
    with SingleTickerProviderStateMixin {
  int? _selectedIndex;
  late final AnimationController _dibujoCtrl;

  // Anima la línea "dibujándose" una vez al aparecer; no se repite en cada rebuild (p.ej. al tocar un punto).
  @override
  void initState() {
    super.initState();
    _dibujoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..forward();
  }

  @override
  void dispose() {
    _dibujoCtrl.dispose();
    super.dispose();
  }

  // Averigua qué punto está más cerca del toque y lo selecciona (o deselecciona si ya lo estaba).
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        final box = context.findRenderObject() as RenderBox;
        final local = box.globalToLocal(details.globalPosition);
        const leftPad = 36.0;
        final chartW = box.size.width - leftPad;
        final stepX =
            widget.data.length > 1 ? chartW / (widget.data.length - 1) : 0.0;
        int closest = 0;
        double minDist = double.infinity;
        for (int i = 0; i < widget.data.length; i++) {
          final dist = (local.dx - (leftPad + i * stepX)).abs();
          if (dist < minDist) {
            minDist = dist;
            closest = i;
          }
        }
        setState(
            () => _selectedIndex = _selectedIndex == closest ? null : closest);
      },
      child: AnimatedBuilder(
        animation: _dibujoCtrl,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _LinePainter(
            data: widget.data,
            labels: widget.labels,
            color: widget.color,
            selectedIndex: _selectedIndex,
            metricLabel: widget.metricLabel,
            progreso: Curves.easeOutCubic.transform(_dibujoCtrl.value),
          ),
        ),
      ),
    );
  }
}

// Dibuja la gráfica de línea: rejilla, eje de valores, la línea con sus puntos, y el tooltip del punto seleccionado.
class _LinePainter extends CustomPainter {
  final List<double> data;
  final List<String> labels;
  final Color color;
  final int? selectedIndex;
  final String metricLabel;
  // 0 = nada dibujado todavía, 1 = línea completa. Ver _InteractiveChartState.
  final double progreso;

  _LinePainter(
      {required this.data,
      required this.labels,
      required this.color,
      this.selectedIndex,
      required this.metricLabel,
      this.progreso = 1});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) {
      return;
    }

    const leftPad = 36.0;
    const bottomPad = 20.0;
    final chartW = size.width - leftPad;
    final chartH = size.height - bottomPad;
    // Guarda: con un único punto data.length-1 sería 0 y la división daría Infinity/NaN.
    final stepX = data.length > 1 ? chartW / (data.length - 1) : 0.0;

    // Impact suele superar 100 (ver calcularImpacto): el eje se adapta al máximo real (100 como suelo), redondeado al siguiente múltiplo de 100.
    final maxDato = data.reduce((a, b) => a > b ? a : b);
    final maxEje = maxDato <= 100 ? 100.0 : (maxDato / 100).ceil() * 100.0;

    final gridPaint = Paint()
      ..color = const Color(0xFF2A2F3E)
      ..strokeWidth = 1;
    final tp = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i <= 4; i++) {
      final y = chartH - (chartH * i / 4);
      canvas.drawLine(Offset(leftPad, y), Offset(size.width, y), gridPaint);
      final val = (maxEje * i / 4).toInt();
      tp.text = TextSpan(
          text: '$val', style: const TextStyle(color: kGray, fontSize: 9));
      tp.layout();
      tp.paint(canvas, Offset(leftPad - tp.width - 4, y - tp.height / 2));
    }

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final linePath = Path();
    final List<Offset> points = [];

    for (int i = 0; i < data.length; i++) {
      final x = leftPad + i * stepX;
      final y = chartH - (data[i] / maxEje) * chartH;
      points.add(Offset(x, y));
      if (i == 0) {
        linePath.moveTo(x, y);
      } else {
        linePath.lineTo(x, y);
      }
    }
    // Se dibuja solo el tramo que toca según 'progreso' (0 a 1), cortando con PathMetrics en vez de mostrar/ocultar segmentos completos, para que se vea "dibujándose" con trazo continuo.
    if (progreso >= 1) {
      canvas.drawPath(linePath, linePaint);
    } else if (progreso > 0) {
      final visible = Path();
      for (final metric in linePath.computeMetrics()) {
        visible.addPath(
            metric.extractPath(0, metric.length * progreso), Offset.zero);
      }
      canvas.drawPath(visible, linePaint);
    }

    // Con muchos puntos las etiquetas se pisan: solo se pintan las que quepan sin solapar (según el ancho real de la más larga), siempre incluyendo primera y última; el resto se ve en el tooltip.
    var anchoEtiquetaMax = 0.0;
    for (final l in labels) {
      tp.text = TextSpan(text: l, style: const TextStyle(fontSize: 9));
      tp.layout();
      if (tp.width > anchoEtiquetaMax) {
        anchoEtiquetaMax = tp.width;
      }
    }
    final anchoEtiquetaAprox = anchoEtiquetaMax + 10;
    final maxEtiquetas = points.length <= 2
        ? points.length
        : (chartW / anchoEtiquetaAprox).floor().clamp(2, points.length);
    final indicesEtiqueta = <int>{};
    if (points.length <= maxEtiquetas) {
      indicesEtiqueta.addAll(List.generate(points.length, (i) => i));
    } else {
      final paso = (points.length - 1) / (maxEtiquetas - 1);
      for (int i = 0; i < maxEtiquetas; i++) {
        indicesEtiqueta.add((i * paso).round());
      }
    }

    // Cada punto aparece solo cuando la línea ya lo ha alcanzado (mismo criterio de índice que 'progreso').
    final puntosVisibles = points.isEmpty
        ? 0
        : (progreso * (points.length - 1)).floor() + 1;
    for (int i = 0; i < points.length && i < puntosVisibles; i++) {
      final isSelected = i == selectedIndex;
      canvas.drawCircle(points[i], isSelected ? 7 : 5, Paint()..color = color);
      canvas.drawCircle(
          points[i], isSelected ? 4 : 3, Paint()..color = Colors.white);
      if (indicesEtiqueta.contains(i)) {
        tp.text = TextSpan(
            text: labels[i], style: const TextStyle(color: kGray, fontSize: 9));
        tp.layout();
        tp.paint(
            canvas, Offset(points[i].dx - tp.width / 2, size.height - 14));
      }
    }

    if (progreso >= 1 && selectedIndex != null && selectedIndex! < points.length) {
      final p = points[selectedIndex!];
      final val = data[selectedIndex!].toInt();
      final dateLabel = labels[selectedIndex!];
      tp.text = TextSpan(
        text: '$dateLabel\n$metricLabel : $val',
        style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            height: 1.6,
            fontWeight: FontWeight.w600),
      );
      tp.layout();
      const pad = 10.0;
      final tw = tp.width + pad * 2;
      final th = tp.height + pad * 2;
      double tx = p.dx - tw / 2;
      double ty = p.dy - th - 10;
      if (tx < leftPad) {
        tx = leftPad;
      }
      if (tx + tw > size.width) {
        tx = size.width - tw;
      }
      if (ty < 0) {
        ty = p.dy + 10;
      }
      final rrect = RRect.fromRectAndRadius(
          Rect.fromLTWH(tx, ty, tw, th), const Radius.circular(8));
      canvas.drawRRect(rrect, Paint()..color = const Color(0xFF252B3B));
      canvas.drawRRect(
          rrect,
          Paint()
            ..color = kGrayDark
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);
      tp.paint(canvas, Offset(tx + pad, ty + pad));
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.data != data ||
      old.selectedIndex != selectedIndex ||
      old.color != color ||
      old.progreso != progreso;
}

// ---- ROUTE MAP WIDGET ----
// Dibuja el recorrido GPS sobre teselas de OpenStreetMap (sin API key), a partir de SesionActividad.recorrido.
class MapaRecorrido extends StatelessWidget {
  final List<Map<String, dynamic>> recorrido;
  const MapaRecorrido({super.key, required this.recorrido});

  @override
  Widget build(BuildContext context) {
    final puntos = recorrido
        .map((p) => LatLng(
            (p['lat'] as num).toDouble(), (p['lng'] as num).toDouble()))
        .toList();
    if (puntos.isEmpty) {
      return const SizedBox.shrink();
    }
    // Encuadre inicial centrado en el recorrido: punto medio entre primero y último, sin paquete adicional de cámara.
    final centro = LatLng(
        (puntos.first.latitude + puntos.last.latitude) / 2,
        (puntos.first.longitude + puntos.last.longitude) / 2);
    return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
            height: 220,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: centro,
                initialZoom: 14,
              ),
              children: [
                TileLayer(
                  // Servidor de teselas estándar de OSM: gratuito, sin API key. El User-Agent es obligatorio según su política de uso.
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.gogait.app',
                ),
                PolylineLayer(polylines: [
                  Polyline(points: puntos, strokeWidth: 4, color: kOrange),
                ]),
                MarkerLayer(markers: [
                  Marker(
                      point: puntos.first,
                      width: 16,
                      height: 16,
                      child: Container(
                          decoration: const BoxDecoration(
                              color: kTeal, shape: BoxShape.circle))),
                  Marker(
                      point: puntos.last,
                      width: 16,
                      height: 16,
                      child: Container(
                          decoration: const BoxDecoration(
                              color: kRed, shape: BoxShape.circle))),
                ]),
              ],
            )));
  }
}

// ---- ACTIVITY DETAIL SCREEN ----
// Detalle de una sesión guardada: heatmap reconstruido, gráfica de fatiga, y edición de título/notas.
class VistaDetalleHistorico extends StatefulWidget {
  final SesionActividad sesion;
  const VistaDetalleHistorico({super.key, required this.sesion});
  @override
  State<VistaDetalleHistorico> createState() => _VistaDetalleHistoricoState();
}

class _VistaDetalleHistoricoState extends State<VistaDetalleHistorico> with IdiomaListenerMixin {
  late TextEditingController _t, _d;
  bool _editing = false;
  String _footFilter = 'both';

  // Precarga los campos editables con el título y las notas guardadas.
  @override
  void initState() {
    super.initState();
    _t = TextEditingController(text: widget.sesion.titulo);
    _d = TextEditingController(text: widget.sesion.descripcion);
  }

  @override
  void dispose() {
    _t.dispose();
    _d.dispose();
    super.dispose();
  }

  // Limpia un valor para usarlo en nombre de fichero: fuera caracteres no válidos en rutas, espacios a "_", nunca vacío.
  String _paraNombreArchivo(String v) {
    final limpio = v
        .trim()
        .replaceAll('/', '-')
        .replaceAll(RegExp(r'[\\:*?"<>|]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    return limpio.isEmpty ? 'sinnombre' : limpio;
  }

  // Envuelve en comillas si hace falta (coma, comillas o salto de línea dentro, p.ej. en notas libres) para seguir siendo CSV válido.
  String _csvEscape(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  // Construye el CSV de resumen: todo lo que la app registra de la sesión en una sola fila.
  String _construirCsvResumen() {
    final s = widget.sesion;
    // Sin muestras crudas, impacto es desconocido (NA), no "0". Balance necesita además señal real del pie izquierdo, si no, NA en vez de un "50" fingido.
    final sinDatosCrudos = !s.tieneImpacto;
    final sinBalance = !s.tieneBalance;
    // impacto_kg necesita peso corporal registrado (ver impactoAKg): si hubo impacto pero no kg, es que faltaba el peso, no que fuese 0.
    final sinPeso = (s.impacto + s.impactoIzq) / 2 > 0 && s.impactoKg <= 0;
    // zancada_ratio necesita altura, pasos y distancia (ver ratioZancada); 0 solo significa que faltaba algún dato.
    final sinZancada = s.zancadaRatio <= 0;
    // strike_index necesita al menos un contacto con fase registrada; sin eso, 0 es "no medido", no "talón puro".
    final sinStrikeDer = !s.tieneStrikeDer;
    final sinStrikeIzq = !s.tieneStrikeIzq;
    // fatiga_index/performance_score ya están guardados de forma permanente, no dependen de datosSesion.
    final sinFatiga = !s.tieneFatiga;
    final performanceScore = calcularPerformanceScore(
      balance: s.balance,
      tieneBalance: s.tieneBalance,
      fatiga: s.tieneFatiga ? s.fatiga : 0,
      tieneFatiga: s.tieneFatiga,
      zancadaRatio: s.zancadaRatio > 0 ? s.zancadaRatio : null,
    );
    // Los 4 ADC de calibración de cada pie: null si la sesión es anterior a este campo o esa plantilla no se calibró.
    String adc(double? v) => v == null ? 'NA' : v.toStringAsFixed(0);
    final buffer = StringBuffer();
    buffer.writeln('titulo,descripcion,tipo,fecha,hora,duracion,pasos,'
        'cadencia_spm,distancia_km,presion_talon_media,'
        'presion_metatarso_media,presion_talon_izq_media,'
        'presion_metatarso_izq_media,balance,impacto,impacto_izq,'
        'impacto_kg,impacto_multiplos_peso,zancada_ratio,strike_index_der,'
        'strike_index_izq,fatiga_index,performance_score,'
        'calib_adc_reposo_der,calib_adc_carga_der,calib_adc_talon_der,'
        'calib_adc_punta_der,calib_adc_reposo_izq,calib_adc_carga_izq,'
        'calib_adc_talon_izq,calib_adc_punta_izq');
    buffer.writeln([
      _csvEscape(s.titulo),
      _csvEscape(s.descripcion),
      s.tipo,
      s.fecha,
      s.hora,
      _csvEscape(s.duracion),
      s.pasos,
      s.cadencia.toStringAsFixed(1),
      s.distanciaKm.toStringAsFixed(3),
      s.presionTalon.toStringAsFixed(1),
      s.presionMeta.toStringAsFixed(1),
      s.presionTalonIzq.toStringAsFixed(1),
      s.presionMetaIzq.toStringAsFixed(1),
      // Desequilibrio (0=simétrico), no el balance crudo interno (50=simétrico), para coincidir con lo que se ve en pantalla.
      sinBalance ? 'NA' : ((s.balance - 50).abs() * 2).toStringAsFixed(1),
      sinDatosCrudos ? 'NA' : s.impacto.toStringAsFixed(1),
      sinDatosCrudos ? 'NA' : s.impactoIzq.toStringAsFixed(1),
      sinDatosCrudos || sinPeso ? 'NA' : s.impactoKg.toStringAsFixed(1),
      // Impacto en múltiplos del peso (ej. 1,5 = 1,5x), deliberadamente sin aplicar el peso real en kg (no exige sinPeso): es el mismo coeficiente que usa impactoAKg, sirve aunque el usuario nunca registrara su peso.
      sinDatosCrudos
          ? 'NA'
          : ((s.impacto + s.impactoIzq) / 2 / 100).toStringAsFixed(2),
      sinZancada ? 'NA' : s.zancadaRatio.toStringAsFixed(2),
      sinStrikeDer ? 'NA' : s.strikeIndexDer.toStringAsFixed(1),
      sinStrikeIzq ? 'NA' : s.strikeIndexIzq.toStringAsFixed(1),
      sinFatiga ? 'NA' : s.fatiga.toStringAsFixed(1),
      performanceScore == null ? 'NA' : performanceScore.toStringAsFixed(1),
      adc(s.adcReposoDer),
      adc(s.adcCargaDer),
      adc(s.adcTalonDer),
      adc(s.adcPuntaDer),
      adc(s.adcReposoIzq),
      adc(s.adcCargaIzq),
      adc(s.adcTalonIzq),
      adc(s.adcPuntaIzq),
    ].join(','));
    return buffer.toString();
  }

  // Construye el CSV con las muestras crudas de la sesión (una fila por muestra recibida de la placa).
  String _construirCsvMuestras() {
    final buffer = StringBuffer();
    buffer.writeln('segundo,talon_izquierdo,metatarso_izquierdo,'
        'talon_derecho,metatarso_derecho,fase_izquierda,fase_derecha');
    for (final d in widget.sesion.datosSesion) {
      // faseIzq/faseDer no existen en sesiones anteriores a este campo: en blanco en vez de "null".
      final faseIzq = d['faseIzq'] ?? '';
      final faseDer = d['faseDer'] ?? '';
      buffer.writeln('${d['seg']},${d['talonIzq']},${d['metaIzq']},'
          '${d['talonDer']},${d['metaDer']},$faseIzq,$faseDer');
    }
    return buffer.toString();
  }

  // Genera los CSV (resumen + muestras crudas si las hay) y abre el diálogo nativo de compartir/guardar.
  Future<void> _exportarCsv() async {
    final dir = await getTemporaryDirectory();
    final usuario = _paraNombreArchivo(usuarioActual?.nombre ?? '');
    final actividad = _paraNombreArchivo(widget.sesion.titulo);
    final fecha = _paraNombreArchivo(widget.sesion.fecha);
    final base = '${usuario}_${actividad}_$fecha';
    final resumenFile = File('${dir.path}/GOGAITSummary_$base.csv');
    await resumenFile.writeAsString(_construirCsvResumen());
    final files = [XFile(resumenFile.path)];
    if (widget.sesion.datosSesion.isNotEmpty) {
      final muestrasFile = File('${dir.path}/GOGAIT_$base.csv');
      await muestrasFile.writeAsString(_construirCsvMuestras());
      files.add(XFile(muestrasFile.path));
    }
    if (!mounted) {
      return;
    }
    await Share.shareXFiles(files,
        text: 'GOGAIT session data: ${widget.sesion.titulo}');
  }

  // Pide confirmación y, si se acepta, borra la sesión del historial y vuelve atrás.
  Future<void> _confirmarBorrado() async {
    final borrar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: kGrayDark)),
        title: Text(tr('delete_activity_title'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        content: Text(tr('action_cannot_be_undone'),
            style: const TextStyle(color: kGray, fontSize: 14)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('cancel_button'), style: const TextStyle(color: kGray))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('delete_button'),
                  style: const TextStyle(color: kRed, fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (borrar == true) {
      historial.remove(widget.sesion);
      await guardarHistorial();
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  // Reconstruye un heatmap aproximado del pie izquierdo a partir de las métricas medias (no hay datos punto a punto); 0 si esa plantilla no tuvo datos reales.
  List<double> get _leftData => List.generate(30, (i) {
        if (i < 14) {
          return widget.sesion.presionMetaIzq;
        }
        if (i < 19) {
          return 10;
        }
        return widget.sesion.presionTalonIzq;
      });

  // Igual que _leftData pero para el pie derecho.
  List<double> get _rightData => List.generate(30, (i) {
        if (i < 14) {
          return widget.sesion.presionMeta;
        }
        if (i < 19) {
          return 10;
        }
        return widget.sesion.presionTalon;
      });

  // Color de la barra de presión según el porcentaje (misma escala que _pressureColor, paleta propia).
  Color _pressureBarColor(int pct) {
    if (pct < 25) {
      return const Color(0xFFFFE082);
    }
    if (pct < 40) {
      return const Color(0xFFFFC107);
    }
    if (pct < 55) {
      return kOrange;
    }
    if (pct < 70) {
      return kRed;
    }
    return const Color(0xFFFF0000);
  }

  // Barra horizontal de progreso para una métrica de presión (con su %).
  Widget _pressureBar(String label, int pct) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Flexible(
          child: Text(label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: const TextStyle(color: kGray, fontSize: 11)),
        ),
        const SizedBox(width: 8),
        Text('$pct%',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 4),
      ClipRRect(
          borderRadius: BorderRadius.circular(3),
          // Barra animada de 0 al valor real, no aparece ya llena.
          child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: (pct / 100).clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, animado, __) => LinearProgressIndicator(
                  // Tope visual 100%; el texto de arriba muestra el % real sin recortar.
                  value: animado,
                  minHeight: 6,
                  backgroundColor: kGrayDark,
                  valueColor: AlwaysStoppedAnimation(_pressureBarColor(pct))))),
      const SizedBox(height: 8),
    ]);
  }

  // Barra de progreso de una métrica que cambia según el filtro de pie elegido (ambos/izquierdo/derecho).
  Widget _metricBar(String label, int pctBoth, int pctLeft, int pctRight,
      Color color, String badge, {String? info, String? etiquetaNumero}) {
    final pct = _footFilter == 'left'
        ? pctLeft
        : _footFilter == 'right'
            ? pctRight
            : pctBoth;
    // Impact pasa "X kg" aquí cuando hay peso registrado, para no repetir el % en una insignia aparte.
    final textoNumero = etiquetaNumero ?? '$pct%';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Flexible(
          child: Row(children: [
            Flexible(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style:
                      const TextStyle(color: Color(0xFFD1D5DB), fontSize: 14)),
            ),
            if (info != null) InfoTip(titulo: label, texto: info),
          ]),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(textoNumero,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
            if (badge.isNotEmpty) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(badge,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w500))),
              ),
            ],
          ]),
        ),
      ]),
      const SizedBox(height: 8),
      ClipRRect(
          borderRadius: BorderRadius.circular(4),
          // Igual que en _pressureBar: anima hacia el nuevo % al aparecer o al cambiar el filtro de pie.
          child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: (pct / 100).clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, animado, __) => LinearProgressIndicator(
                  // Igual que en _pressureBar: barra tope a 100%, el número de arriba muestra el real.
                  value: animado,
                  minHeight: 8,
                  backgroundColor: kGrayDark,
                  valueColor: AlwaysStoppedAnimation(color)))),
    ]);
  }

  // Selector Both/Left Foot/Right Foot que filtra las métricas mostradas.
  Widget _footSelector() {
    return Row(
        children: ['both', 'left', 'right'].map((f) {
      final label = f == 'both'
          ? tr('both_label')
          : f == 'left'
              ? tr('left_foot')
              : tr('right_foot');
      final sel = _footFilter == f;
      return Expanded(
          child: GestureDetector(
        onTap: () => setState(() => _footFilter = f),
        child: Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: sel ? kOrange.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: sel ? kOrange : kGrayDark),
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: TextStyle(
                  color: sel ? kOrange : kGray,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ),
      ));
    }).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
          child: Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
              GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          color: kCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kGrayDark)),
                      child: const Icon(Icons.chevron_left,
                          color: Colors.white, size: 20))),
              Expanded(
                  child: Text(tr('activity_details'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600))),
              GestureDetector(
                  onTap: () {
                    if (_editing) {
                      widget.sesion.titulo = _t.text;
                      widget.sesion.descripcion = _d.text;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(tr('changes_saved')),
                          backgroundColor: kCard,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))));
                    }
                    setState(() => _editing = !_editing);
                  },
                  child: Icon(_editing ? Icons.check : Icons.edit_outlined,
                      color: kOrange, size: 20)),
              const SizedBox(width: 16),
              GestureDetector(
                  onTap: _confirmarBorrado,
                  child:
                      const Icon(Icons.delete_outline, color: kRed, size: 20)),
            ])),

        Expanded(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _editing
                          ? TextField(
                              controller: _t,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700),
                              decoration: InputDecoration(
                                  filled: true,
                                  fillColor: kCard,
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide:
                                          const BorderSide(color: kOrange)),
                                  focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide:
                                          const BorderSide(color: kOrange))))
                          : Text(_t.text,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Row(children: [
                        const Icon(Icons.calendar_today_outlined,
                            color: kGray, size: 16),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(() {
                            final parts = widget.sesion.fecha.split('/');
                            if (parts.length >= 2) {
                              final mes = int.tryParse(parts[1]) ?? 1;
                              // Abreviatura del mes traducido, no lista fija en inglés (respeta idioma activo).
                              final mesAbrev = tr('month_$mes')
                                  .substring(
                                      0,
                                      tr('month_$mes').length < 3
                                          ? tr('month_$mes').length
                                          : 3);
                              // Sesiones antiguas sin año en 'fecha': se recupera del id (timestamp completo).
                              final anio = parts.length >= 3
                                  ? parts[2]
                                  : DateTime.tryParse(widget.sesion.id)
                                          ?.year
                                          .toString() ??
                                      '';
                              final sufijo = anio.isEmpty ? '' : ' $anio';
                              return '${parts[0]} $mesAbrev$sufijo';
                            }
                            return widget.sesion.fecha;
                          }(),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style:
                                  const TextStyle(color: kGray, fontSize: 14)),
                        ),
                        const SizedBox(width: 20),
                        const Icon(Icons.access_time_outlined,
                            color: kGray, size: 16),
                        const SizedBox(width: 6),
                        Text(() {
                          final h = widget.sesion.hora.split(':');
                          if (h.length == 2) {
                            final hora = int.tryParse(h[0]) ?? 0;
                            final min = h[1];
                            final ampm = hora >= 12 ? 'PM' : 'AM';
                            final hora12 = hora > 12
                                ? hora - 12
                                : hora == 0
                                    ? 12
                                    : hora;
                            return '$hora12:$min $ampm';
                          }
                          return widget.sesion.hora;
                        }(),
                            style: const TextStyle(color: kGray, fontSize: 14)),
                      ]),
                      const SizedBox(height: 16),

                      Text(tr('notes_label'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15)),
                      const SizedBox(height: 8),
                      _editing
                          ? TextField(
                              controller: _d,
                              maxLines: 3,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                  filled: true,
                                  fillColor: kCard,
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide:
                                          const BorderSide(color: kOrange)),
                                  focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide:
                                          const BorderSide(color: kOrange))))
                          : Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                  color: kCard,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: kGrayDark)),
                              child: Text(
                                  _d.text.isEmpty ? tr('no_notes') : _d.text,
                                  style: const TextStyle(
                                      color: Color(0xFFD1D5DB), fontSize: 14))),
                      const SizedBox(height: 20),
                      // Se oculta en modo edición: solo queda visible lo editable (título y notas).
                      if (!_editing) ...[
                      Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                              color: kCard,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: kGrayDark.withValues(alpha: 0.5))),
                          child: Builder(builder: (context) {
                            final s = widget.sesion;
                            final score = calcularPerformanceScore(
                              balance: s.balance,
                              tieneBalance: s.tieneBalance,
                              fatiga: s.tieneFatiga ? s.fatiga : 0,
                              tieneFatiga: s.tieneFatiga,
                              zancadaRatio:
                                  s.zancadaRatio > 0 ? s.zancadaRatio : null,
                            );
                            // Combina balance/fatiga/zancada; N/A si faltan datos en las tres.
                            final etiqueta = score == null
                                ? 'N/A'
                                : score >= 85
                                    ? tr('score_excellent')
                                    : score >= 70
                                        ? tr('score_good')
                                        : score >= 50
                                            ? tr('score_fair')
                                            : tr('score_needs_improvement');
                            return Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment:
                                    CrossAxisAlignment.center,
                                children: [
                                  Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(tr('performance_score'),
                                            style: const TextStyle(
                                                color: kGray, fontSize: 14)),
                                        InfoTip(
                                            titulo: tr('performance_score'),
                                            texto:
                                                tr('performance_score_info')),
                                      ]),
                                  const SizedBox(height: 24),
                                  SizedBox(
                                      width: 160,
                                      height: 160,
                                      // Anima de 0 al score real, como en _CircProgress.
                                      child: TweenAnimationBuilder<double>(
                                          tween: Tween(
                                              begin: 0,
                                              end: score ?? 0),
                                          duration:
                                              const Duration(milliseconds: 900),
                                          curve: Curves.easeOutCubic,
                                          builder: (context, animado, __) =>
                                              Stack(
                                                  alignment: Alignment.center,
                                                  children: [
                                                    SizedBox(
                                                        width: 160,
                                                        height: 160,
                                                        child:
                                                            CircularProgressIndicator(
                                                                value: score ==
                                                                        null
                                                                    ? 0
                                                                    : animado /
                                                                        100,
                                                                strokeWidth: 14,
                                                                backgroundColor:
                                                                    kGrayDark,
                                                                valueColor:
                                                                    AlwaysStoppedAnimation(
                                                                        score ==
                                                                                null
                                                                            ? kGray
                                                                            : kOrange))),
                                                    Text(
                                                        score == null
                                                            ? '0'
                                                            : '${animado.round()}',
                                                        style: const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 36,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w700)),
                                                  ]))),
                                  const SizedBox(height: 24),
                                  Text(etiqueta,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16)),
                                  const SizedBox(height: 8),
                                ]);
                          })),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(
                            child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              color: kCard,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: kGrayDark.withValues(alpha: 0.5))),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.access_time_outlined,
                                    color: kGray, size: 22),
                                const SizedBox(height: 10),
                                Text(widget.sesion.duracion,
                                    style: const TextStyle(
                                        color: kOrange,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text(tr('duration_label'),
                                    style:
                                        const TextStyle(color: kGray, fontSize: 12)),
                              ]),
                        )),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              color: kCard,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: kGrayDark.withValues(alpha: 0.5))),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.do_not_step,
                                    color: kGray, size: 22),
                                const SizedBox(height: 10),
                                Text(
                                    '${widget.sesion.distanciaKm.toStringAsFixed(2)} km',
                                    style: const TextStyle(
                                        color: kRed,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text(tr('metric_distance'),
                                    style:
                                        const TextStyle(color: kGray, fontSize: 12)),
                              ]),
                        )),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                            child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              color: kCard,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: kGrayDark.withValues(alpha: 0.5))),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.trending_up,
                                    color: kGray, size: 22),
                                const SizedBox(height: 10),
                                Text('${widget.sesion.cadencia.round()} spm',
                                    style: const TextStyle(
                                        color: kPurple,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(tr('metric_cadence'),
                                          style: const TextStyle(
                                              color: kGray, fontSize: 12)),
                                      InfoTip(
                                          titulo: tr('metric_cadence'),
                                          texto: tr('cadence_info')),
                                    ]),
                              ]),
                        )),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              color: kCard,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: kGrayDark.withValues(alpha: 0.5))),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.show_chart,
                                    color: kGray, size: 22),
                                const SizedBox(height: 10),
                                Text('${widget.sesion.pasos}',
                                    style: const TextStyle(
                                        color: kTeal,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text(tr('steps_label'),
                                    style:
                                        const TextStyle(color: kGray, fontSize: 12)),
                              ]),
                        )),
                      ]),
                      const SizedBox(height: 12),
                      Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              color: kCard,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: kGrayDark.withValues(alpha: 0.5))),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.straighten,
                                    color: kGray, size: 22),
                                const SizedBox(height: 10),
                                Text(
                                    widget.sesion.zancadaRatio <= 0
                                        ? 'N/A'
                                        : '${(widget.sesion.zancadaRatio * 100).round()}%',
                                    style: const TextStyle(
                                        color: kOrange,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Row(mainAxisSize: MainAxisSize.min, children: [
                                  Flexible(
                                    child: Text(tr('stride_vs_expected'),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        style: const TextStyle(
                                            color: kGray, fontSize: 12)),
                                  ),
                                  InfoTip(
                                      titulo: tr('stride_vs_expected'),
                                      texto: tr('stride_info')),
                                ]),
                              ])),
                      const SizedBox(height: 16),

                      // Sesiones grabadas antes de añadir este campo, o sin GPS, no muestran esta tarjeta.
                      if (widget.sesion.recorrido.isNotEmpty) ...[
                        GogaitCard(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(tr('route_label'),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15)),
                                  const SizedBox(height: 12),
                                  MapaRecorrido(
                                      recorrido: widget.sesion.recorrido),
                                ])),
                        const SizedBox(height: 16),
                      ],

                      Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                              color: kCard,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: kGrayDark.withValues(alpha: 0.5))),
                          child: Column(children: [
                            Text(tr('pressure_analysis_summary'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15)),
                            const SizedBox(height: 20),
                            Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  FootHeatmapWidget(
                                      data: _leftData,
                                      label: tr('left_foot'),
                                      isLeft: true),
                                  FootHeatmapWidget(
                                      data: _rightData,
                                      label: tr('right_foot'),
                                      isLeft: false),
                                ]),
                            const SizedBox(height: 16),
                            const Divider(color: Color(0xFF374151)),
                            const SizedBox(height: 12),
                            Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                        tr('pressure_distribution_breakdown'),
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13)),
                                  ),
                                  InfoTip(
                                      titulo:
                                          tr('pressure_distribution_breakdown'),
                                      texto: tr('heel_metatarsal_info')),
                                ]),
                            const SizedBox(height: 12),
                            Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(tr('left_foot'),
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                                color: kGray, fontSize: 11)),
                                        const SizedBox(height: 8),
                                        _pressureBar(tr('heel_label'),
                                            widget.sesion.presionTalonIzq.round()),
                                        _pressureBar(tr('metatarsal_label'),
                                            widget.sesion.presionMetaIzq.round()),
                                      ])),
                                  const SizedBox(width: 16),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(tr('right_foot'),
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                                color: kGray, fontSize: 11)),
                                        const SizedBox(height: 8),
                                        _pressureBar(
                                            tr('heel_label'), widget.sesion.presionTalon.round()),
                                        _pressureBar(tr('metatarsal_label'),
                                            widget.sesion.presionMeta.round()),
                                      ])),
                                ]),
                            const SizedBox(height: 12),
                            const Divider(color: Color(0xFF374151)),
                            const SizedBox(height: 8),
                            Text(tr('pressure_level'),
                                style: const TextStyle(color: kGray, fontSize: 11)),
                            const SizedBox(height: 6),
                            Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(tr('low_label'),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        style: const TextStyle(
                                            color: kGray, fontSize: 11)),
                                  ),
                                  ...[
                                    0xFFFFE082,
                                    0xFFFFC107,
                                    0xFFFF8A00,
                                    0xFFFF3D57,
                                    0xFFFF0000,
                                    0xFFB026FF
                                  ].map((c) => Container(
                                      width: 20,
                                      height: 6,
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 2),
                                      decoration: BoxDecoration(
                                          color: Color(c),
                                          borderRadius:
                                              BorderRadius.circular(3)))),
                                  const Text(' >100%',
                                      style: TextStyle(
                                          color: kGray, fontSize: 11)),
                                ]),
                          ])),
                      const SizedBox(height: 16),

                      Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                              color: kCard,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: kGrayDark.withValues(alpha: 0.5))),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(tr('biomechanical_metrics'),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15)),
                                const SizedBox(height: 12),
                                _footSelector(),
                                const SizedBox(height: 20),
                                Builder(builder: (context) {
                                  // Sin señal del pie izq., balance es NA (no un 50 fingido); pctBoth es % de desequilibrio, no reparto real (0=simétrico, 100=todo en un pie).
                                  final sinBalance = !widget.sesion.tieneBalance;
                                  final balancePct = sinBalance
                                      ? 0
                                      : widget.sesion.balance.round();
                                  final desequilibrioPct = sinBalance
                                      ? 0
                                      : ((widget.sesion.balance - 50).abs() * 2)
                                          .round();
                                  // El badge aclara qué pie domina; solo aplica en Both.
                                  final ladoBalance = _footFilter != 'both'
                                      ? ''
                                      : balancePct > 50
                                          ? tr('right_dominant')
                                          : balancePct < 50
                                              ? tr('left_dominant')
                                              : tr('symmetric_label');
                                  return _metricBar(
                                      tr('metric_balance'),
                                      desequilibrioPct,
                                      sinBalance ? 0 : 100 - balancePct,
                                      balancePct,
                                      kGray,
                                      sinBalance ? '' : ladoBalance,
                                      info: tr('balance_info'));
                                }),
                                const SizedBox(height: 16),
                                Builder(builder: (context) {
                                  final sinDatos = !widget.sesion.tieneImpacto;
                                  // Sin peso registrado se muestra el % en vez de kg (impactoKg es media de ambos pies).
                                  final sinPeso = (widget.sesion.impacto +
                                              widget.sesion.impactoIzq) /
                                          2 >
                                      0 &&
                                      widget.sesion.impactoKg <= 0;
                                  final impactoDerPct = sinDatos
                                      ? 0
                                      : widget.sesion.impacto.round();
                                  final impactoIzqPct = sinDatos
                                      ? 0
                                      : widget.sesion.impactoIzq.round();
                                  final impactoBothPct = sinDatos
                                      ? 0
                                      : ((widget.sesion.impacto +
                                                  widget.sesion.impactoIzq) /
                                              2)
                                          .round();
                                  // El % de respaldo sigue el filtro Left/Right/Both seleccionado.
                                  final pctSegunFiltro = _footFilter == 'left'
                                      ? impactoIzqPct
                                      : _footFilter == 'right'
                                          ? impactoDerPct
                                          : impactoBothPct;
                                  // El peso no se guarda (solo impactoKg del Both); se reconstruye para mostrar kg en Left/Right: peso = impactoKg / (impactoBothPct/100).
                                  final pesoEnSesion =
                                      (!sinPeso && impactoBothPct > 0)
                                          ? widget.sesion.impactoKg /
                                              (impactoBothPct / 100)
                                          : null;
                                  final numeroPrincipal = pesoEnSesion == null
                                      ? null
                                      : '${(pctSegunFiltro / 100 * pesoEnSesion).round()} kg';
                                  return _metricBar(
                                      tr('metric_impact'),
                                      impactoBothPct,
                                      impactoIzqPct,
                                      impactoDerPct,
                                      kGray,
                                      sinDatos ? 'N/A' : '',
                                      info: tr('impact_info'),
                                      etiquetaNumero: numeroPrincipal);
                                }),
                                const SizedBox(height: 16),
                                Builder(builder: (context) {
                                  final tiene = widget.sesion.tieneFatiga;
                                  final fatiga =
                                      tiene ? widget.sesion.fatiga : 0.0;
                                  final tramos = widget.sesion.tramosFatiga;
                                  // Color fijo (no por umbral); el dinámico se queda solo en Quick Metrics.
                                  const colorFatiga = kGray;
                                  return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment
                                                    .spaceBetween,
                                            children: [
                                              Flexible(
                                                child: Row(children: [
                                                  Flexible(
                                                    child: Text(
                                                        tr('fatigue_index'),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        maxLines: 1,
                                                        style: const TextStyle(
                                                            color: Color(
                                                                0xFFD1D5DB),
                                                            fontSize: 14)),
                                                  ),
                                                  InfoTip(
                                                      titulo:
                                                          tr('fatigue_index'),
                                                      texto:
                                                          tr('fatigue_index_info')),
                                                ]),
                                              ),
                                              const SizedBox(width: 8),
                                              Row(children: [
                                                Text(
                                                    tiene
                                                        ? '${fatiga.round()}%'
                                                        : '0%',
                                                    style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w600)),
                                                const SizedBox(width: 8),
                                                Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 10,
                                                        vertical: 3),
                                                    decoration: BoxDecoration(
                                                        color: colorFatiga
                                                            .withValues(
                                                                alpha: 0.12),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(20)),
                                                    child: Text(
                                                        !tiene
                                                            ? 'N/A'
                                                            : fatiga >= 20
                                                                ? tr('fatigue_rising')
                                                                : tr('fatigue_stable'),
                                                        style: const TextStyle(
                                                            color:
                                                                colorFatiga,
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w500))),
                                              ]),
                                            ]),
                                        const SizedBox(height: 8),
                                        TweenAnimationBuilder<double>(
                                            tween: Tween(begin: 0, end: 1),
                                            duration: const Duration(
                                                milliseconds: 900),
                                            curve: Curves.easeOutCubic,
                                            builder: (context, progreso, __) =>
                                                CustomPaint(
                                                    size: const Size(
                                                        double.infinity, 70),
                                                    painter: _FatiguePainter(
                                                        tramos, progreso))),
                                      ]);
                                }),
                                const SizedBox(height: 4),
                                Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        child: Text(tr('start_label'),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                            style: const TextStyle(
                                                color: kGray, fontSize: 10)),
                                      ),
                                      Flexible(
                                        child: Text(tr('mid_label'),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                                color: kGray, fontSize: 10)),
                                      ),
                                      Flexible(
                                        child: Text(tr('end_label'),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                            textAlign: TextAlign.end,
                                            style: const TextStyle(
                                                color: kGray, fontSize: 10)),
                                      ),
                                    ]),
                                const SizedBox(height: 16),
                                Builder(builder: (context) {
                                  // strikeIndexDer/Izq son independientes: cada pct se apaga con su propio flag.
                                  final strikeDerPct = widget.sesion.tieneStrikeDer
                                      ? widget.sesion.strikeIndexDer.round()
                                      : 0;
                                  final strikeIzqPct = widget.sesion.tieneStrikeIzq
                                      ? widget.sesion.strikeIndexIzq.round()
                                      : 0;
                                  final sinAmbos = !widget.sesion.tieneStrikeDer &&
                                      !widget.sesion.tieneStrikeIzq;
                                  final strikeBothPct = sinAmbos
                                      ? 0
                                      : !widget.sesion.tieneStrikeDer
                                          ? strikeIzqPct
                                          : !widget.sesion.tieneStrikeIzq
                                              ? strikeDerPct
                                              : ((strikeDerPct + strikeIzqPct) / 2)
                                                  .round();
                                  // Sin datos para el pie (o pies) del filtro Both/Left/Right seleccionado.
                                  final sinDatosFiltro = _footFilter == 'left'
                                      ? !widget.sesion.tieneStrikeIzq
                                      : _footFilter == 'right'
                                          ? !widget.sesion.tieneStrikeDer
                                          : sinAmbos;
                                  final pctFiltro = _footFilter == 'left'
                                      ? strikeIzqPct
                                      : _footFilter == 'right'
                                          ? strikeDerPct
                                          : strikeBothPct;
                                  final badge = sinDatosFiltro
                                      ? 'N/A'
                                      : pctFiltro < 34
                                          ? tr('strike_heel')
                                          : pctFiltro < 67
                                              ? tr('strike_midfoot')
                                              : tr('strike_forefoot');
                                  return _metricBar(
                                      tr('strike_index'),
                                      strikeBothPct,
                                      strikeIzqPct,
                                      strikeDerPct,
                                      kYellow,
                                      badge,
                                      info: tr('strike_index_info'));
                                }),
                              ])),
                      const SizedBox(height: 16),

                      Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                kOrange.withValues(alpha: 0.08),
                                kRed.withValues(alpha: 0.08)
                              ]),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: kOrange.withValues(alpha: 0.2))),
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                        gradient: kGradient,
                                        borderRadius: BorderRadius.circular(8)),
                                    child: const Icon(Icons.my_location,
                                        color: Colors.white, size: 16)),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(tr('insights_title'),
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15)),
                                      const SizedBox(height: 6),
                                      Text(generarInsights(widget.sesion),
                                          style: const TextStyle(
                                              color: Color(0xFFD1D5DB),
                                              fontSize: 13,
                                              height: 1.5)),
                                    ])),
                              ])),
                      const SizedBox(height: 16),
                      ],

                      // El tick del header ya guarda y sale de edición; no hace falta un botón "Save Changes" aquí.
                      if (!_editing)
                        GestureDetector(
                            onTap: _exportarCsv,
                            child: Container(
                                height: 56,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                    color: kCard,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: kGrayDark)),
                                alignment: Alignment.center,
                                child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.file_download_outlined,
                                          color: kTeal, size: 18),
                                      const SizedBox(width: 8),
                                      Text(tr('export_as_csv'),
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 16)),
                                    ]))),
                    ]))),
      ])),
    );
  }
}

// Gráfica de fatiga: une los 3 valores de impacto medio (inicio/mitad/fin, tramosFatiga). Línea plana = sin datos suficientes (los 3 a 0), no ausencia de fatiga.
class _FatiguePainter extends CustomPainter {
  final List<double> tramos; // [inicio, mitad, fin], cada uno 0-100
  // 0 = nada dibujado, 1 = línea completa.
  final double progreso;
  _FatiguePainter(this.tramos, [this.progreso = 1]);

  @override
  void paint(Canvas canvas, Size size) {
    final maximo = tramos.isEmpty
        ? 0.0
        : tramos.reduce((a, b) => a > b ? a : b);
    final subiendo = tramos.length == 3 && tramos[2] > tramos[0];
    final color = maximo <= 0
        ? kGray
        : subiendo
            ? kRed
            : kTeal;
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    // Margen arriba/abajo para que los puntos no toquen el borde; sin máximo (todo a 0), línea plana centrada.
    double yPara(double valor) {
      if (maximo <= 0) {
        return size.height * 0.5;
      }
      final margen = size.height * 0.15;
      return size.height - margen - (valor / maximo) * (size.height - 2 * margen);
    }

    final puntos = List.generate(3, (i) {
      final x = size.width * (i / 2);
      final v = tramos.length == 3 ? tramos[i] : 0.0;
      return Offset(x, yPara(v));
    });
    final path = Path()..moveTo(puntos[0].dx, puntos[0].dy);
    for (final p in puntos.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    // Igual que en _LinePainter: recorta el trazo según 'progreso' para que se vea dibujándose.
    if (progreso >= 1) {
      canvas.drawPath(path, linePaint);
    } else if (progreso > 0) {
      final visible = Path();
      for (final metric in path.computeMetrics()) {
        visible.addPath(
            metric.extractPath(0, metric.length * progreso), Offset.zero);
      }
      canvas.drawPath(visible, linePaint);
    }
    final puntosVisibles = (progreso * 2).floor() + 1; // 3 puntos, 2 tramos
    for (int i = 0; i < puntos.length && i < puntosVisibles; i++) {
      canvas.drawCircle(puntos[i], 4, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _FatiguePainter oldDelegate) =>
      oldDelegate.tramos != tramos || oldDelegate.progreso != progreso;
}

// ---- SETTINGS SCREEN ----
// Ajustes del usuario: datos personales y físicos editables, foto, y cierre de sesión.
class VistaAjustes extends StatefulWidget {
  const VistaAjustes({super.key});
  @override
  State<VistaAjustes> createState() => _VistaAjustesState();
}

class _VistaAjustesState extends State<VistaAjustes> with IdiomaListenerMixin {
  late TextEditingController _nC, _apellidoC, _emailC;
  late double _altura, _peso, _shoeSize;
  late String _genero, _arco, _patologia;
  DateTime? _fechaNac;
  bool _editing = false;

  // Fecha de nacimiento formateada como "June 25, 2026".
  String get _fechaStr => fechaNacAMostrar(_fechaNac);

  // Precarga los campos con los datos del usuario, con valores por defecto si aún no hay medidas guardadas.
  @override
  void initState() {
    super.initState();
    _nC = TextEditingController(text: usuarioActual?.nombre ?? '');
    _apellidoC = TextEditingController(text: usuarioActual?.apellido ?? '');
    _emailC = TextEditingController(text: usuarioActual?.email ?? '');
    _patologia = usuarioActual?.patologia ?? 'none';
    _altura = (usuarioActual?.altura ?? 0) < 140 ? 170 : usuarioActual!.altura;
    _peso = (usuarioActual?.peso ?? 0) < 40 ? 70 : usuarioActual!.peso;
    _shoeSize =
        (usuarioActual?.shoeSize ?? 0) < 35 ? 42 : usuarioActual!.shoeSize;
    _genero = (usuarioActual?.genero.isEmpty ?? true)
        ? 'Male'
        : usuarioActual!.genero;
    _arco =
        (usuarioActual?.arco.isEmpty ?? true) ? 'Normal' : usuarioActual!.arco;
    final cump = usuarioActual?.cumpleanos ?? '';
    if (cump.isNotEmpty) {
      _fechaNac = fechaNacDesdeGuardado(cump);
    }
  }

  @override
  void dispose() {
    _nC.dispose();
    _apellidoC.dispose();
    _emailC.dispose();
    super.dispose();
  }

  // Pide confirmación y, si se acepta, elimina la cuenta y todos sus datos.
  Future<void> _confirmarEliminarCuenta() async {
    final eliminar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: kGrayDark)),
        title: Text(tr('delete_account_title'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        content: Text(
            tr('delete_account_msg'),
            style: const TextStyle(color: kGray, fontSize: 14)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('cancel_button'), style: const TextStyle(color: kGray))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('delete_button'),
                  style: const TextStyle(color: kRed, fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (eliminar == true) {
      await _eliminarCuenta();
    }
  }

  // Borra la cuenta de Firebase primero; las claves locales solo se borran si eso tiene éxito, para no dejar la cuenta a medias si Firebase falla.
  Future<void> _eliminarCuenta() async {
    final email = FirebaseAuth.instance.currentUser?.email;
    try {
      await FirebaseAuth.instance.currentUser?.delete();
      final prefs = await SharedPreferences.getInstance();
      if (email != null && email.isNotEmpty) {
        final sufijo = '_$email';
        final claves =
            prefs.getKeys().where((k) => k.endsWith(sufijo)).toList();
        for (final clave in claves) {
          await prefs.remove(clave);
        }
      }
      usuarioActual = null;
      historial = [];
      if (!mounted) {
        return;
      }
      Navigator.pushAndRemoveUntil(
          context,
          gogaitRoute(builder: (_) => const VistaBienvenida()),
          (_) => false);
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }
      final mensaje = e.code == 'requires-recent-login'
          ? tr('err_reauth_required')
          : '${tr('err_deleting_account')}: ${e.message}';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(mensaje)));
    }
  }

  // Guarda los cambios en SharedPreferences y en el Usuario en memoria, y sale del modo edición.
  void _save() async {
    final cumpleGuardar =
        _fechaNac != null ? fechaNacAGuardar(_fechaNac!) : '';
    final p = await SharedPreferences.getInstance();
    await p.setString(_claveUsuario('nombre'), _nC.text);
    await p.setString(_claveUsuario('apellido'), _apellidoC.text);
    await p.setString(_claveUsuario('cumpleanos'), cumpleGuardar);
    await p.setDouble(_claveUsuario('altura'), _altura);
    await p.setDouble(_claveUsuario('peso'), _peso);
    await p.setDouble(_claveUsuario('shoeSize'), _shoeSize);
    await p.setString(_claveUsuario('genero'), _genero);
    await p.setString(_claveUsuario('arco'), _arco);
    await p.setString(_claveUsuario('patologia'), _patologia);
    usuarioActual?.nombre = _nC.text;
    usuarioActual?.apellido = _apellidoC.text;
    usuarioActual?.cumpleanos = cumpleGuardar;
    usuarioActual?.altura = _altura;
    usuarioActual?.peso = _peso;
    usuarioActual?.shoeSize = _shoeSize;
    usuarioActual?.genero = _genero;
    usuarioActual?.arco = _arco;
    usuarioActual?.patologia = _patologia == 'none' ? null : _patologia;
    setState(() => _editing = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr('changes_saved')),
          backgroundColor: kCard,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
    }
  }

  // Fila de solo lectura: icono + etiqueta + valor (modo no edición).
  Widget _infoRow(String label, String value, IconData icon,
      {Color iconColor = kOrange}) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 18)),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: kGray, fontSize: 14)),
          const SizedBox(width: 8),
          // Expanded para que el valor quede a la derecha y haga ellipsis si es largo.
          Expanded(
              child: Text(value,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500))),
        ]));
  }

  // Fila editable: icono + etiqueta + widget de edición (dropdown, texto, selector de fecha...).
  Widget _editRow(String label, IconData icon, Widget valueWidget,
      {Color iconColor = kOrange}) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 18)),
          const SizedBox(width: 12),
          SizedBox(
              width: 80,
              child: Text(label,
                  style: const TextStyle(color: kGray, fontSize: 14))),
          Expanded(child: valueWidget),
        ]));
  }

  // Desplegable genérico con el estilo de la app (género, tipo de arco...).
  Widget _dropdown(
      String value, List<String> options, void Function(String) onChanged,
      {String Function(String)? labelFor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
          color: kBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kGrayDark)),
      child: DropdownButton<String>(
        value: value,
        isDense: true,
        isExpanded: true,
        dropdownColor: kCard,
        underline: const SizedBox(),
        style: const TextStyle(
            color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
        icon: const Icon(Icons.keyboard_arrow_down, color: kGray, size: 18),
        items: options
            .map((o) => DropdownMenuItem(
                value: o, child: Text(labelFor != null ? labelFor(o) : o)))
            .toList(),
        onChanged: (v) {
          if (v != null) {
            setState(() => onChanged(v));
          }
        },
      ),
    );
  }

  // Mismo estilo que _dropdown, pero el valor guardado (slug) y el label mostrado son distintos, así que no encaja en _dropdown.
  Widget _dropdownCondicion() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
          color: kBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kGrayDark)),
      child: DropdownButton<String>(
        value: _patologia,
        isDense: true,
        isExpanded: true,
        dropdownColor: kCard,
        underline: const SizedBox(),
        style: const TextStyle(
            color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
        icon: const Icon(Icons.keyboard_arrow_down, color: kGray, size: 18),
        items: _condicionesPie
            .map((c) =>
                DropdownMenuItem(value: c['value'], child: Text(c['label']!)))
            .toList(),
        onChanged: (v) {
          if (v != null) {
            setState(() => _patologia = v);
          }
        },
      ),
    );
  }

  // Campo de texto compacto para editar un valor en línea (nombre, patología).
  Widget _inlineText(TextEditingController ctrl) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: kBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kGrayDark)),
      child: TextField(
        controller: ctrl,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: const InputDecoration(
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
          child: Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
              GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          color: kCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kGrayDark)),
                      child: const Icon(Icons.chevron_left,
                          color: Colors.white, size: 20))),
              Expanded(
                  child: Text(tr('profile_title'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600))),
              GestureDetector(
                  onTap:
                      _editing ? _save : () => setState(() => _editing = true),
                  child: Icon(_editing ? Icons.check : Icons.edit_outlined,
                      color: kOrange, size: 22)),
            ])),

        Expanded(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final x = await ImagePicker()
                          .pickImage(source: ImageSource.gallery);
                      if (x != null) {
                        final p = await SharedPreferences.getInstance();
                        await p.setString(_claveUsuario('fotoPath'), x.path);
                        if (mounted) {
                          setState(() => usuarioActual?.fotoPath = x.path);
                        }
                      }
                    },
                    child: Stack(alignment: Alignment.bottomRight, children: [
                      Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                              gradient: kGradientFull, shape: BoxShape.circle),
                          child: usuarioActual?.fotoPath != null
                              ? ClipOval(
                                  child: Image.file(
                                      File(usuarioActual!.fotoPath!),
                                      fit: BoxFit.cover))
                              : const Icon(Icons.person,
                                  color: Colors.white, size: 48)),
                      Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                              color: kTeal, shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt,
                              color: Colors.white, size: 16)),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  Text(
                      (() {
                        final partes = [
                          usuarioActual?.nombre,
                          usuarioActual?.apellido
                        ].where((s) => s != null && s.isNotEmpty).join(' ');
                        return partes.isEmpty ? tr('user_fallback') : partes;
                      })(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w600)),
                  Text(miembroDesde(),
                      style: const TextStyle(color: kGray, fontSize: 13)),
                  const SizedBox(height: 24),

                  GogaitCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tr('personal_data'),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15)),
                            const SizedBox(height: 12),
                            if (_editing) ...[
                              _editRow(tr('name_label'), Icons.person_outline,
                                  _inlineText(_nC),
                                  iconColor: kOrange),
                              const Divider(
                                  color: Color(0xFF374151), height: 20),
                              _editRow(tr('last_name'), Icons.person_outline,
                                  _inlineText(_apellidoC),
                                  iconColor: kOrange),
                              const Divider(
                                  color: Color(0xFF374151), height: 20),
                              _editRow(
                                  tr('email_label'),
                                  Icons.email_outlined,
                                  Text(_emailC.text,
                                      style: const TextStyle(
                                          color: kGray, fontSize: 14),
                                      textAlign: TextAlign.right),
                                  iconColor: kOrange),
                              const Divider(
                                  color: Color(0xFF374151), height: 20),
                              _editRow(
                                  tr('date_of_birth_break'),
                                  Icons.calendar_today_outlined,
                                  pillFechaNacimiento(_fechaNac, () async {
                                    final picked = await elegirFechaNacimiento(
                                        context, _fechaNac);
                                    if (picked != null) {
                                      setState(() => _fechaNac = picked);
                                    }
                                  }),
                                  iconColor: kOrange),
                            ] else ...[
                              _infoRow(tr('name_label'), _nC.text, Icons.person_outline,
                                  iconColor: kOrange),
                              const Divider(
                                  color: Color(0xFF374151), height: 1),
                              _infoRow(tr('last_name'), _apellidoC.text,
                                  Icons.person_outline,
                                  iconColor: kOrange),
                              const Divider(
                                  color: Color(0xFF374151), height: 1),
                              _infoRow(
                                  tr('email_label'), _emailC.text, Icons.email_outlined,
                                  iconColor: kOrange),
                              const Divider(
                                  color: Color(0xFF374151), height: 1),
                              _infoRow(tr('date_of_birth'), _fechaStr,
                                  Icons.calendar_today_outlined,
                                  iconColor: kOrange),
                            ],
                          ])),
                  const SizedBox(height: 12),

                  GogaitCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tr('physical_metrics'),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15)),
                            const SizedBox(height: 12),
                            if (_editing) ...[
                              _editRow(
                                  tr('height'),
                                  Icons.height,
                                  _dropdown(
                                      '${_altura.toInt()}',
                                      List.generate(81, (i) => '${140 + i}'),
                                      (v) => _altura = double.parse(v)),
                                  iconColor: kRed),
                              const Divider(
                                  color: Color(0xFF374151), height: 20),
                              _editRow(
                                  tr('weight'),
                                  Icons.monitor_weight_outlined,
                                  _dropdown(
                                      '${_peso.toInt()}',
                                      List.generate(111, (i) => '${40 + i}'),
                                      (v) => _peso = double.parse(v)),
                                  iconColor: kRed),
                              const Divider(
                                  color: Color(0xFF374151), height: 20),
                              _editRow(
                                  tr('shoe_size_label'),
                                  Icons.directions_walk_outlined,
                                  _dropdown(
                                      '${_shoeSize.toInt()}',
                                      List.generate(16, (i) => '${35 + i}'),
                                      (v) => _shoeSize = double.parse(v)),
                                  iconColor: kRed),
                              const Divider(
                                  color: Color(0xFF374151), height: 20),
                              _editRow(
                                  tr('gender'),
                                  Icons.person_outline,
                                  _dropdown(_genero, ['Male', 'Female'],
                                      (v) => _genero = v,
                                      labelFor: (v) =>
                                          v == 'Male' ? tr('male') : tr('female')),
                                  iconColor: kRed),
                            ] else ...[
                              _infoRow(tr('height'), '${_altura.toInt()} cm',
                                  Icons.height,
                                  iconColor: kRed),
                              const Divider(
                                  color: Color(0xFF374151), height: 1),
                              _infoRow(tr('weight'), '${_peso.toInt()} kg',
                                  Icons.monitor_weight_outlined,
                                  iconColor: kRed),
                              const Divider(
                                  color: Color(0xFF374151), height: 1),
                              _infoRow(tr('shoe_size_label'), '${_shoeSize.toInt()} EU',
                                  Icons.directions_walk_outlined,
                                  iconColor: kRed),
                              const Divider(
                                  color: Color(0xFF374151), height: 1),
                              _infoRow(tr('gender'),
                                  _genero == 'Male' ? tr('male') : tr('female'),
                                  Icons.person_outline,
                                  iconColor: kRed),
                            ],
                          ])),
                  const SizedBox(height: 12),

                  GogaitCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tr('biomechanics_title'),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15)),
                            const SizedBox(height: 12),
                            if (_editing) ...[
                              _editRow(
                                  tr('foot_arch_label'),
                                  Icons.architecture,
                                  _dropdown(_arco, ['Flat', 'Normal', 'High'],
                                      (v) => _arco = v,
                                      labelFor: (v) => v == 'Flat'
                                          ? tr('arch_flat')
                                          : v == 'High'
                                              ? tr('arch_high')
                                              : tr('arch_normal')),
                                  iconColor: kYellow),
                              const Divider(
                                  color: Color(0xFF374151), height: 20),
                              _editRow(tr('condition_label'), Icons.favorite_outline,
                                  _dropdownCondicion(),
                                  iconColor: kYellow),
                            ] else ...[
                              _infoRow(
                                  tr('foot_arch_label'),
                                  _arco == 'Flat'
                                      ? tr('arch_flat')
                                      : _arco == 'High'
                                          ? tr('arch_high')
                                          : tr('arch_normal'),
                                  Icons.architecture,
                                  iconColor: kYellow),
                              const Divider(
                                  color: Color(0xFF374151), height: 1),
                              _infoRow(
                                  tr('condition_label'),
                                  etiquetaCondicion(_patologia),
                                  Icons.favorite_outline,
                                  iconColor: kYellow),
                            ],
                          ])),
                  const SizedBox(height: 12),

                  // Solo fuera de modo edición, para no mezclarlo con los controles de edición del perfil.
                  if (!_editing) ...[
                    GogaitCard(
                        onTap: () => Navigator.push(
                            context,
                            gogaitRoute(
                                builder: (_) => const VistaGuiaMetricas())),
                        padding: const EdgeInsets.all(16),
                        child: Row(children: [
                          Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                  color: kTeal.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10)),
                              child: const Icon(Icons.menu_book_outlined,
                                  color: kTeal, size: 18)),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Text(tr('metrics_guide_title'),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15))),
                          const Icon(Icons.chevron_right,
                              color: kGray, size: 20),
                        ])),
                    const SizedBox(height: 20),
                  ],

                  // Solo cierra sesión, no toca datos locales de otras cuentas del dispositivo.
                  if (!_editing)
                    GestureDetector(
                      onTap: () async {
                        await FirebaseAuth.instance.signOut();
                        usuarioActual = null;
                        if (!context.mounted) {
                          return;
                        }
                        Navigator.pushAndRemoveUntil(
                            context,
                            gogaitRoute(
                                builder: (_) => const VistaBienvenida()),
                            (_) => false);
                      },
                      child: Container(
                          width: double.infinity,
                          height: 52,
                          decoration: BoxDecoration(
                              color: kRed.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: kRed.withValues(alpha: 0.3))),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.logout, color: kRed, size: 20),
                                const SizedBox(width: 8),
                                Text(tr('sign_out'),
                                    style: const TextStyle(
                                        color: kRed,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15)),
                              ])),
                    ),

                  // Borra cuenta y datos locales; requiere confirmación explícita por ser irreversible.
                  if (!_editing) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _confirmarEliminarCuenta,
                      child: Container(
                          width: double.infinity,
                          height: 52,
                          decoration: BoxDecoration(
                              color: kRed.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(16),
                              border:
                                  Border.all(color: kGrayDark)),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.delete_forever_outlined,
                                    color: kGray, size: 20),
                                const SizedBox(width: 8),
                                Text(tr('delete_account'),
                                    style: const TextStyle(
                                        color: kGray,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15)),
                              ])),
                    ),
                  ],
                ]))),
      ])),
    );
  }
}

// ---- METRICS GUIDE SCREEN ----
// Explica qué mide cada métrica, de dónde sale el número y cómo interpretarlo.
class VistaGuiaMetricas extends StatelessWidget {
  const VistaGuiaMetricas({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLang>(
        valueListenable: appLang,
        builder: (context, _, __) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
          child: Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
              GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          color: kCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kGrayDark)),
                      child: const Icon(Icons.chevron_left,
                          color: Colors.white, size: 20))),
              const SizedBox(width: 12),
              Expanded(
                child: Text(tr('metrics_guide_title'),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600)),
              ),
            ])),
        Expanded(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          tr('metrics_guide_subtitle'),
                          style: const TextStyle(color: kGray, fontSize: 13)),
                      const SizedBox(height: 20),
                      _tarjetaMetrica(
                        icon: Icons.my_location,
                        color: kTeal,
                        titulo: tr('metric_balance'),
                        definicion: tr('mg_balance_def'),
                        formula: 'Balance = 100 ×\n\n'
                            '  ΣPresRight\n'
                            '  ──────────────────\n'
                            '  ΣPresLeft + ΣPresRight',
                        variables: [
                          tr('mg_balance_var1'),
                          tr('mg_balance_var2'),
                        ],
                        valores: [
                          (kTeal, tr('mg_balance_val1')),
                          (kOrange, tr('mg_balance_val2')),
                          (kRed, tr('mg_balance_val3')),
                        ],
                        nota: tr('mg_balance_nota'),
                        dondeAparece: tr('mg_balance_where'),
                      ),
                      const SizedBox(height: 14),
                      _tarjetaMetrica(
                        icon: Icons.speed,
                        color: kOrange,
                        titulo: tr('metric_impact'),
                        definicion: tr('mg_impact_def'),
                        formula: 'Impact = avg(step peak)\n\n'
                            'Impact (kg) =\n\n'
                            '  Impact\n'
                            '  ─────── × Weight\n'
                            '    100',
                        variables: [
                          tr('mg_impact_var1'),
                          tr('mg_impact_var2'),
                        ],
                        valores: [
                          (kTeal, tr('mg_impact_val1')),
                          (kOrange, tr('mg_impact_val2')),
                          (kRed, tr('mg_impact_val3')),
                        ],
                        nota: tr('mg_impact_nota'),
                        dondeAparece: tr('mg_impact_where'),
                      ),
                      const SizedBox(height: 14),
                      _tarjetaMetrica(
                        icon: Icons.trending_down,
                        color: kRed,
                        titulo: tr('fatigue_index'),
                        definicion: tr('mg_fatigue_def'),
                        formula: 'Fatigue Index = 100 ×\n\n'
                            '  ImpactEnd −\n'
                            '  ImpactStart\n'
                            '  ─────────────\n'
                            '  ImpactStart',
                        variables: [
                          tr('mg_fatigue_var1'),
                          tr('mg_fatigue_var2'),
                        ],
                        valores: [
                          (kTeal, tr('mg_fatigue_val1')),
                          (kRed, tr('mg_fatigue_val2')),
                        ],
                        nota: tr('mg_fatigue_nota'),
                        dondeAparece: tr('mg_fatigue_where'),
                      ),
                      const SizedBox(height: 14),
                      _tarjetaMetrica(
                        icon: Icons.do_not_step,
                        color: kYellow,
                        titulo: tr('mg_heel_metatarsal_title'),
                        definicion: tr('mg_heel_metatarsal_def'),
                        formula: 'w_heel = 1.0 → Heel Strike\n'
                            'w_heel = 0.5 → Midstance\n'
                            'w_heel = 0.0 → Propulsion/Swing',
                        variables: [
                          tr('mg_heel_metatarsal_var1'),
                          tr('mg_heel_metatarsal_var2'),
                        ],
                        valores: [
                          (kYellow, tr('mg_heel_metatarsal_val1')),
                          (kYellow, tr('mg_heel_metatarsal_val2')),
                          (kYellow, tr('mg_heel_metatarsal_val3')),
                        ],
                        nota: tr('mg_heel_metatarsal_nota'),
                        dondeAparece: tr('mg_heel_metatarsal_where'),
                      ),
                      const SizedBox(height: 14),
                      _tarjetaMetrica(
                        icon: Icons.compare_arrows,
                        color: kYellow,
                        titulo: tr('strike_index'),
                        definicion: tr('mg_strike_def'),
                        formula: 'Strike Index =\n\n'
                            '  avg(100 × (1 − w_heel_mag))',
                        variables: [
                          tr('mg_strike_var1'),
                          tr('mg_strike_var2'),
                        ],
                        valores: [
                          (kYellow, tr('mg_strike_val1')),
                          (kYellow, tr('mg_strike_val2')),
                          (kYellow, tr('mg_strike_val3')),
                        ],
                        nota: tr('mg_strike_nota'),
                        dondeAparece: tr('mg_strike_where'),
                      ),
                      const SizedBox(height: 14),
                      _tarjetaMetrica(
                        icon: Icons.emoji_events_outlined,
                        color: kPurple,
                        titulo: tr('performance_score'),
                        definicion: tr('mg_performance_def'),
                        formula: 'Score = 100 −\n\n'
                            '  avg(PenBalance,\n'
                            '      PenFatigue,\n'
                            '      PenStride)',
                        variables: [
                          tr('mg_performance_var1'),
                          tr('mg_performance_var2'),
                          tr('mg_performance_var3'),
                        ],
                        valores: [
                          (kPurple, tr('mg_performance_val1')),
                          (kPurple, tr('mg_performance_val2')),
                          (kPurple, tr('mg_performance_val3')),
                          (kPurple, tr('mg_performance_val4')),
                        ],
                        nota: tr('mg_performance_nota'),
                        dondeAparece: tr('mg_performance_where'),
                      ),
                      const SizedBox(height: 14),
                      _tarjetaMetrica(
                        icon: Icons.trending_up,
                        color: kOrange,
                        titulo: tr('metric_cadence'),
                        definicion: tr('mg_cadence_def'),
                        formula: 'Cadence =\n\n'
                            '  Steps\n'
                            '  ────────\n'
                            '  Minute',
                        dondeAparece: tr('mg_cadence_where'),
                      ),
                      const SizedBox(height: 14),
                      _tarjetaMetrica(
                        icon: Icons.straighten,
                        color: kOrange,
                        titulo: tr('stride_vs_expected'),
                        definicion: tr('mg_stride_def'),
                        formula: 'StrideRatio =\n\n'
                            '  Distance / Steps\n'
                            '  ──────────────────\n'
                            '  ExpectedStride\n\n'
                            'ExpectedStride = Height × k',
                        variables: [
                          tr('mg_stride_var1'),
                        ],
                        valores: [
                          (kOrange, tr('mg_stride_val1')),
                          (kOrange, tr('mg_stride_val2')),
                          (kOrange, tr('mg_stride_val3')),
                        ],
                        nota: tr('mg_stride_nota'),
                        dondeAparece: tr('mg_stride_where'),
                      ),
                      const SizedBox(height: 20),
                      Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                kOrange.withValues(alpha: 0.08),
                                kRed.withValues(alpha: 0.08)
                              ]),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: kOrange.withValues(alpha: 0.2))),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  const Icon(Icons.my_location,
                                      color: kOrange, size: 16),
                                  const SizedBox(width: 8),
                                  Text(tr('about_insights_title'),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14)),
                                ]),
                                const SizedBox(height: 8),
                                Text(
                                    tr('about_insights_intro'),
                                    style: const TextStyle(
                                        color: kGray,
                                        fontSize: 12,
                                        height: 1.4)),
                                const SizedBox(height: 8),
                                _reglaInsight(tr('about_insights_rule_1')),
                                _reglaInsight(tr('about_insights_rule_2')),
                                _reglaInsight(tr('about_insights_rule_3')),
                                _reglaInsight(tr('about_insights_rule_4')),
                                _reglaInsight(tr('about_insights_rule_5')),
                                _reglaInsight(tr('about_insights_rule_6')),
                              ])),
                      const SizedBox(height: 12),
                    ]))),
      ])),
    );
        });
  }

  Widget _reglaInsight(String texto) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
            padding: EdgeInsets.only(top: 5),
            child: Icon(Icons.circle, color: kGray, size: 4)),
        const SizedBox(width: 8),
        Expanded(
            child: Text(texto,
                style:
                    const TextStyle(color: kGray, fontSize: 12, height: 1.4))),
      ]));

  // Puntos de color: variables de la fórmula o valores típicos (ver colorDesequilibrio/colorImpacto/etc.).
  Widget _listaConPuntos(List<String> lineas, Color color) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lineas
          .map((l) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Icon(Icons.circle, color: color, size: 4)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(l,
                            style: const TextStyle(
                                color: kGray, fontSize: 12, height: 1.35))),
                  ])))
          .toList());

  // Como _listaConPuntos pero con color propio por línea (mismos colores que colorDesequilibrio/colorImpacto/colorFatiga).
  Widget _listaValoresConPuntos(List<(Color, String)> items) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Icon(Icons.circle, color: item.$1, size: 9)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(item.$2,
                            style: const TextStyle(
                                color: kGray, fontSize: 12, height: 1.35))),
                  ])))
          .toList());

  // Etiqueta en mayúsculas para separar secciones dentro de la tarjeta.
  Widget _seccionLabel(String texto, Color color) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(texto.toUpperCase(),
          style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5)));

  Widget _tarjetaMetrica({
    required IconData icon,
    required Color color,
    required String titulo,
    required String definicion,
    String? formula,
    List<String> variables = const [],
    List<(Color, String)> valores = const [],
    String? nota,
    required String dondeAparece,
  }) {
    return GogaitCard(
        padding: const EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 18)),
            const SizedBox(width: 12),
            Expanded(
                child: Text(titulo,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15))),
          ]),
          const SizedBox(height: 8),
          Text(definicion,
              style: const TextStyle(
                  color: Color(0xFFD1D5DB), fontSize: 13, height: 1.4)),
          if (formula != null) ...[
            const SizedBox(height: 8),
            Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                    color: kBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withValues(alpha: 0.25))),
                child: Text(formula,
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontFamily: 'monospace',
                        height: 1.4))),
          ],
          if (variables.isNotEmpty) ...[
            const SizedBox(height: 10),
            _seccionLabel(tr('mg_section_vars'), color),
            _listaConPuntos(variables, color),
          ],
          if (valores.isNotEmpty) ...[
            const SizedBox(height: 10),
            _seccionLabel(tr('mg_section_valores'), color),
            _listaValoresConPuntos(valores),
          ],
          if (nota != null) ...[
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(Icons.info_outline, color: kGray, size: 12)),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(nota,
                      style: const TextStyle(
                          color: kGray,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          height: 1.3))),
            ]),
          ],
          const SizedBox(height: 10),
          Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: kGrayDark.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8)),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.place_outlined, color: kGray, size: 12),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(dondeAparece,
                        style: const TextStyle(
                            color: kGray,
                            fontSize: 11,
                            fontStyle: FontStyle.italic))),
              ])),
        ]));
  }
}
