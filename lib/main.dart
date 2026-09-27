import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

const kBg = Color(0xFF07060B);
const kBg2 = Color(0xFF0C0A14);
const kSurface = Color(0xFF14121C);
const kSurfaceAlt = Color(0xFF1A1826);
const kSurfaceHi = Color(0xFF211D30);
const kIndigo = Color(0xFF7C6CFF);
const kViolet = Color(0xFFA377FF);
const kEmerald = Color(0xFF17E3A8);
const kDanger = Color(0xFFFF5C7A);
const kAmber = Color(0xFFFFC66B);
const kTextPrimary = Color(0xFFF3F1FA);
const kTextSecondary = Color(0xFFA6A2BE);
const kTextFaint = Color(0xFF716C8C);
const kBorder = Color(0x1FFFFFFF);
const kBorderSoft = Color(0x14FFFFFF);

const kRadiusSm = 10.0;
const kRadiusMd = 16.0;
const kRadiusLg = 22.0;

const kMonoFont = 'monospace';

const kGradientHeader = LinearGradient(
  colors: [kIndigo, kViolet],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

void main() {
  runApp(const SingularityApp());
}

class SingularityApp extends StatelessWidget {
  const SingularityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calculadora de Curvas Elípticas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: kBg,
        splashFactory: InkRipple.splashFactory,
        colorScheme: const ColorScheme.dark(
          primary: kIndigo,
          secondary: kEmerald,
          surface: kSurface,
          error: kDanger,
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: kIndigo,
          selectionColor: Color(0x557C6CFF),
          selectionHandleColor: kIndigo,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: kBg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: kSurfaceAlt,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kRadiusMd),
            side: const BorderSide(color: kBorderSoft),
          ),
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: kBg2,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(kRadiusSm),
            borderSide: const BorderSide(color: kBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(kRadiusSm),
            borderSide: const BorderSide(color: kBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(kRadiusSm),
            borderSide: const BorderSide(color: kIndigo, width: 1.6),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(kRadiusSm),
            borderSide: const BorderSide(color: kDanger),
          ),
          labelStyle: const TextStyle(color: kTextSecondary),
          floatingLabelStyle: const TextStyle(color: kIndigo),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kIndigo,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(kRadiusSm),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: kSurface,
          selectedColor: kIndigo.withValues(alpha: 0.22),
          labelStyle: const TextStyle(color: kTextPrimary, fontWeight: FontWeight.w600),
          side: const BorderSide(color: kBorder),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusSm)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        dividerTheme: const DividerThemeData(color: kBorder, thickness: 1),
        scrollbarTheme: ScrollbarThemeData(
          thumbColor: WidgetStateProperty.all(kTextFaint.withValues(alpha: 0.5)),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: kTextPrimary),
        ).apply(bodyColor: kTextPrimary, displayColor: kTextPrimary),
      ),
      home: const HomeScreen(),
    );
  }
}

List<BoxShadow> glowShadow(Color color, {double blur = 28, double alpha = 0.16}) => [
      BoxShadow(
        color: color.withValues(alpha: alpha),
        blurRadius: blur,
        spreadRadius: -6,
        offset: const Offset(0, 10),
      ),
    ];

/// Fondo decorativo con manchas de luz difuminadas, usado detrás del contenido principal.
class AppBackdrop extends StatelessWidget {
  final Widget child;
  const AppBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: Container(color: kBg)),
        Positioned(top: -140, right: -100, child: _blob(kIndigo, 320)),
        Positioned(bottom: -160, left: -120, child: _blob(kEmerald, 300)),
        Positioned(top: 220, left: -80, child: _blob(kViolet, 220)),
        child,
      ],
    );
  }

  Widget _blob(Color color, double size) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: 0.20), color.withValues(alpha: 0.0)],
          ),
        ),
      ),
    );
  }
}
