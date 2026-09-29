import 'package:flutter_test/flutter_test.dart';
import 'package:singularidad_calculator/math/ec_math.dart';

/// Conteo por fuerza bruta de #E(F_p), incluyendo el punto al infinito.
int bruteForceCardinality(int a, int b, int p) {
  int count = 1; // 𝒪
  for (int x = 0; x < p; x++) {
    final int rhs = (((x * x % p) * x % p) + (a % p) * x % p + b) % p;
    final int r = (rhs % p + p) % p;
    for (int y = 0; y < p; y++) {
      if (y * y % p == r) count++;
    }
  }
  return count;
}

const List<int> _primes = [
  5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73,
  79, 83, 89, 97, 101, 103, 107, 109, 113, 127, 131, 137, 139, 149, 151,
];

void main() {
  group('isPrime', () {
    test('acepta primos y rechaza compuestos', () {
      for (final p in _primes) {
        expect(isPrime(BigInt.from(p)), isTrue, reason: '$p es primo');
      }
      for (final n in [0, 1, 4, 9, 15, 21, 25, 49, 91, 121, 169, 341, 561, 1105, 1729, 2465]) {
        expect(isPrime(BigInt.from(n)), isFalse, reason: '$n es compuesto');
      }
    });

    test('es determinista entre llamadas', () {
      for (final n in [561, 1105, 1729, 2821, 6601, 8911]) {
        final first = isPrime(BigInt.from(n));
        for (int i = 0; i < 25; i++) {
          expect(isPrime(BigInt.from(n)), first);
        }
      }
    });
  });

  group('modInverse', () {
    test('devuelve el inverso correcto', () {
      for (final p in _primes) {
        final bp = BigInt.from(p);
        for (int a = 1; a < p; a++) {
          final inv = modInverse(BigInt.from(a), bp);
          expect((BigInt.from(a) * inv) % bp, BigInt.one, reason: 'a=$a p=$p');
        }
      }
    });

    test('lanza excepción cuando no existe inverso', () {
      expect(() => modInverse(BigInt.from(4), BigInt.from(8)), throwsException);
      expect(() => modInverse(BigInt.zero, BigInt.from(7)), throwsException);
    });
  });

  group('sqrtModPrime', () {
    test('encuentra la raíz de todo residuo cuadrático', () {
      for (final p in _primes) {
        final bp = BigInt.from(p);
        final squares = <int>{for (int y = 0; y < p; y++) y * y % p};
        for (int n = 0; n < p; n++) {
          final root = sqrtModPrime(BigInt.from(n), bp);
          if (squares.contains(n)) {
            expect(root, isNotNull, reason: 'n=$n p=$p es residuo cuadrático');
            expect((root! * root) % bp, BigInt.from(n), reason: 'n=$n p=$p');
          } else {
            expect(root, isNull, reason: 'n=$n p=$p no es residuo');
          }
        }
      }
    });

    test('cubre primos p ≡ 1 (mod 4), el caso que fallaba', () {
      for (final p in _primes.where((p) => p % 4 == 1)) {
        final bp = BigInt.from(p);
        for (int y = 0; y < p; y++) {
          final n = BigInt.from(y * y % p);
          final root = sqrtModPrime(n, bp);
          expect(root, isNotNull, reason: 'p=$p n=$n');
          expect((root! * root) % bp, n);
        }
      }
    });
  });

  group('getPoints / cardinalidad', () {
    test('coincide con la fuerza bruta en todas las curvas no singulares', () {
      for (final p in _primes.where((p) => p <= 61)) {
        for (int a = 0; a < p; a++) {
          for (int b = 0; b < p; b++) {
            final disc = (4 * a * a * a + 27 * b * b) % p;
            if (disc == 0) continue; // singular
            final curve = EllipticCurve(a: BigInt.from(a), b: BigInt.from(b), p: BigInt.from(p));
            expect(
              curve.getPoints().length,
              bruteForceCardinality(a, b, p),
              reason: 'y² = x³ + ${a}x + $b mod $p',
            );
          }
        }
      }
    });

    test('todos los puntos devueltos están sobre la curva y no hay duplicados', () {
      for (final p in _primes) {
        final bp = BigInt.from(p);
        for (int a = 0; a < 5; a++) {
          for (int b = 0; b < 5; b++) {
            if ((4 * a * a * a + 27 * b * b) % p == 0) continue;
            final curve = EllipticCurve(a: BigInt.from(a), b: BigInt.from(b), p: bp);
            final pts = curve.getPoints();
            expect(pts.toSet().length, pts.length, reason: 'duplicados en p=$p a=$a b=$b');
            for (final pt in pts.where((e) => !e.isInfinity)) {
              final lhs = (pt.y! * pt.y!) % bp;
              final rhs = (pt.x!.pow(3) + BigInt.from(a) * pt.x! + BigInt.from(b)) % bp;
              expect(lhs, rhs, reason: '$pt no está en la curva p=$p a=$a b=$b');
            }
          }
        }
      }
    });

    test('cumple el teorema de Hasse', () {
      for (final p in _primes) {
        for (int a = 0; a < 7; a++) {
          for (int b = 0; b < 7; b++) {
            if ((4 * a * a * a + 27 * b * b) % p == 0) continue;
            final curve = EllipticCurve(a: BigInt.from(a), b: BigInt.from(b), p: BigInt.from(p));
            final n = curve.getPoints().length;
            // |#E − (p+1)| ≤ 2√p, comparado al cuadrado para evitar dobles.
            final diff = (n - (p + 1)).abs();
            expect(diff * diff, lessThanOrEqualTo(4 * p), reason: 'Hasse falla en p=$p a=$a b=$b (#E=$n)');
          }
        }
      }
    });
  });

  group('aritmética del grupo', () {
    test('el conjunto de puntos es cerrado bajo la suma', () {
      for (final p in [11, 13, 17, 19, 23, 29, 37, 41]) {
        for (int a = 0; a < 4; a++) {
          for (int b = 1; b < 4; b++) {
            if ((4 * a * a * a + 27 * b * b) % p == 0) continue;
            final curve = EllipticCurve(a: BigInt.from(a), b: BigInt.from(b), p: BigInt.from(p));
            final pts = curve.getPoints();
            final set = pts.toSet();
            for (final p1 in pts) {
              for (final p2 in pts) {
                expect(set.contains(curve.add(p1, p2)), isTrue,
                    reason: '$p1 + $p2 se sale del grupo (p=$p a=$a b=$b)');
              }
            }
          }
        }
      }
    });

    test('#E · P = 𝒪 para todo punto (Lagrange)', () {
      for (final p in [11, 13, 17, 19, 23, 29, 37, 41, 53, 61]) {
        for (int a = 0; a < 4; a++) {
          for (int b = 1; b < 4; b++) {
            if ((4 * a * a * a + 27 * b * b) % p == 0) continue;
            final curve = EllipticCurve(a: BigInt.from(a), b: BigInt.from(b), p: BigInt.from(p));
            final pts = curve.getPoints();
            final card = BigInt.from(pts.length);
            for (final pt in pts) {
              expect(curve.multiply(card, pt).isInfinity, isTrue,
                  reason: '#E·$pt != 𝒪 (p=$p a=$a b=$b, #E=$card)');
            }
          }
        }
      }
    });

    test('la suma es conmutativa y asociativa', () {
      final curve = EllipticCurve(a: BigInt.two, b: BigInt.from(3), p: BigInt.from(17));
      final pts = curve.getPoints();
      for (final p1 in pts) {
        for (final p2 in pts) {
          expect(curve.add(p1, p2), curve.add(p2, p1));
          for (final p3 in pts) {
            expect(curve.add(curve.add(p1, p2), p3), curve.add(p1, curve.add(p2, p3)));
          }
        }
      }
    });

    test('multiply coincide con la suma repetida, y k negativo invierte', () {
      final curve = EllipticCurve(a: BigInt.two, b: BigInt.from(3), p: BigInt.from(17));
      final pts = curve.getPoints();
      for (final pt in pts) {
        ECPoint acc = const ECPoint.infinity();
        for (int k = 1; k <= 25; k++) {
          acc = curve.add(acc, pt);
          expect(curve.multiply(BigInt.from(k), pt), acc, reason: 'k=$k P=$pt');
          expect(curve.add(curve.multiply(BigInt.from(-k), pt), acc).isInfinity, isTrue,
              reason: '(-k)P + kP != 𝒪 con k=$k P=$pt');
        }
      }
    });

    test('findOrder devuelve el orden real del punto', () {
      for (final p in [11, 13, 17, 19, 23, 29, 37]) {
        for (int a = 0; a < 4; a++) {
          for (int b = 1; b < 4; b++) {
            if ((4 * a * a * a + 27 * b * b) % p == 0) continue;
            final curve = EllipticCurve(a: BigInt.from(a), b: BigInt.from(b), p: BigInt.from(p));
            final pts = curve.getPoints();
            final card = BigInt.from(pts.length);
            for (final pt in pts) {
              final order = curve.findOrder(pt, card);
              expect(curve.multiply(order, pt).isInfinity, isTrue, reason: 'orden $order de $pt');
              expect(card % order, BigInt.zero, reason: 'el orden debe dividir a #E');
              // Mínimo: ningún k menor anula el punto.
              for (BigInt k = BigInt.one; k < order; k += BigInt.one) {
                expect(curve.multiply(k, pt).isInfinity, isFalse,
                    reason: '$k·$pt = 𝒪 pero findOrder dijo $order');
              }
            }
          }
        }
      }
    });
  });

  group('curvas singulares', () {
    test('detecta el discriminante nulo', () {
      expect(EllipticCurve(a: BigInt.zero, b: BigInt.zero, p: BigInt.from(17)).isSingular(), isTrue);
      expect(EllipticCurve(a: BigInt.two, b: BigInt.from(3), p: BigInt.from(17)).isSingular(), isFalse);
      for (final p in _primes.where((p) => p <= 61)) {
        for (int a = 0; a < p; a++) {
          for (int b = 0; b < p; b++) {
            final expected = (4 * a * a * a + 27 * b * b) % p == 0;
            final curve = EllipticCurve(a: BigInt.from(a), b: BigInt.from(b), p: BigInt.from(p));
            expect(curve.isSingular(), expected, reason: 'a=$a b=$b p=$p');
          }
        }
      }
    });

    test('rechaza p no primo o p <= 3', () {
      expect(() => EllipticCurve(a: BigInt.one, b: BigInt.one, p: BigInt.from(15)), throwsException);
      expect(() => EllipticCurve(a: BigInt.one, b: BigInt.one, p: BigInt.from(3)), throwsException);
    });
  });
}
