/// Algoritmo Extendido de Euclides para inverso modular.
/// Lanza excepción si gcd(a, m) != 1, es decir, si el inverso no existe.
BigInt modInverse(BigInt a, BigInt m) {
  if (m <= BigInt.zero) throw Exception("El módulo debe ser positivo");
  if (m == BigInt.one) return BigInt.zero;

  a = a % m;
  if (a < BigInt.zero) a += m;

  BigInt r0 = m, r1 = a;
  BigInt s0 = BigInt.zero, s1 = BigInt.one;

  while (r1 != BigInt.zero) {
    final BigInt q = r0 ~/ r1;
    final BigInt r = r0 - q * r1;
    r0 = r1;
    r1 = r;
    final BigInt s = s0 - q * s1;
    s0 = s1;
    s1 = s;
  }

  if (r0 != BigInt.one) throw Exception("$a no tiene inverso modular mod $m");
  return (s0 % m + m) % m;
}

/// Bases de Miller-Rabin que hacen el test determinista para n < 3.3·10^24.
const List<int> _mrWitnesses = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37];

/// Test de primalidad de Miller-Rabin con bases fijas (determinista en el
/// rango que maneja la app, y sin resultados que varíen entre ejecuciones).
bool isPrime(BigInt n) {
  if (n < BigInt.two) return false;

  for (final int w in _mrWitnesses) {
    final BigInt bw = BigInt.from(w);
    if (n == bw) return true;
    if (n % bw == BigInt.zero) return false;
  }

  BigInt d = n - BigInt.one;
  int s = 0;
  while (d.isEven) {
    d ~/= BigInt.two;
    s++;
  }

  for (final int w in _mrWitnesses) {
    BigInt x = BigInt.from(w).modPow(d, n);
    if (x == BigInt.one || x == n - BigInt.one) continue;

    bool composite = true;
    for (int r = 1; r < s; r++) {
      x = (x * x) % n;
      if (x == n - BigInt.one) {
        composite = false;
        break;
      }
    }
    if (composite) return false;
  }
  return true;
}

/// Representa un punto en la curva elíptica
class ECPoint {
  final BigInt? x;
  final BigInt? y;
  final bool isInfinity;

  const ECPoint(this.x, this.y) : isInfinity = false;
  const ECPoint.infinity() : x = null, y = null, isInfinity = true;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ECPoint) return false;
    if (isInfinity && other.isInfinity) return true;
    return !isInfinity && !other.isInfinity && x == other.x && y == other.y;
  }

  @override
  int get hashCode => isInfinity ? 0 : Object.hash(x, y);

  @override
  String toString() {
    if (isInfinity) return '𝒪';
    return '($x, $y)';
  }
}

class EllipticCurve {
  final BigInt a;
  final BigInt b;
  final BigInt p;

  EllipticCurve({required BigInt a, required BigInt b, required this.p})
      : a = (a % p + p) % p,
        b = (b % p + p) % p {
    if (p <= BigInt.from(3)) throw Exception("p debe ser mayor a 3");
    if (!isPrime(p)) throw Exception("p debe ser primo");
  }

  bool isSingular() {
    BigInt disc = (BigInt.from(4) * a.pow(3) + BigInt.from(27) * b.pow(2)) % p;
    return disc == BigInt.zero;
  }

  ECPoint add(ECPoint P, ECPoint Q) {
    if (P.isInfinity) return Q;
    if (Q.isInfinity) return P;

    if (P.x == Q.x) {
      if ((P.y! + Q.y!) % p == BigInt.zero) return const ECPoint.infinity();
      return doublePoint(P);
    }

    BigInt num = (Q.y! - P.y!) % p;
    BigInt den = (Q.x! - P.x!) % p;
    if (den < BigInt.zero) den += p;
    if (num < BigInt.zero) num += p;

    BigInt lambda = (num * modInverse(den, p)) % p;
    
    BigInt x3 = (lambda.pow(2) - P.x! - Q.x!) % p;
    if (x3 < BigInt.zero) x3 += p;
    
    BigInt y3 = (lambda * (P.x! - x3) - P.y!) % p;
    if (y3 < BigInt.zero) y3 += p;

    return ECPoint(x3, y3);
  }

  ECPoint doublePoint(ECPoint P) {
    if (P.isInfinity) return P;
    if (P.y == BigInt.zero) return const ECPoint.infinity();

    BigInt num = (BigInt.from(3) * P.x!.pow(2) + a) % p;
    BigInt den = (BigInt.from(2) * P.y!) % p;
    if (den < BigInt.zero) den += p;
    if (num < BigInt.zero) num += p;

    BigInt lambda = (num * modInverse(den, p)) % p;

    BigInt x3 = (lambda.pow(2) - BigInt.from(2) * P.x!) % p;
    if (x3 < BigInt.zero) x3 += p;

    BigInt y3 = (lambda * (P.x! - x3) - P.y!) % p;
    if (y3 < BigInt.zero) y3 += p;

    return ECPoint(x3, y3);
  }

  ECPoint multiply(BigInt k, ECPoint P) {
    if (P.isInfinity || k == BigInt.zero) return const ECPoint.infinity();
    if (k < BigInt.zero) {
      // k * P = (-k) * (-P)
      ECPoint negP = ECPoint(P.x, (-P.y!) % p);
      return multiply(-k, negP);
    }

    ECPoint R = const ECPoint.infinity();
    ECPoint base = P;
    String kBin = k.toRadixString(2);
    
    for (int i = kBin.length - 1; i >= 0; i--) {
      if (kBin[i] == '1') {
        R = add(R, base);
      }
      base = doublePoint(base);
    }
    return R;
  }

  BigInt findOrder(ECPoint P, BigInt card) {
    if (P.isInfinity) return BigInt.one;
    
    List<BigInt> divisors = [];
    for (BigInt i = BigInt.one; i * i <= card; i += BigInt.one) {
      if (card % i == BigInt.zero) {
        divisors.add(i);
        if (i * i != card) {
          divisors.add(card ~/ i);
        }
      }
    }
    divisors.sort((a, b) => a.compareTo(b));
    
    for (BigInt d in divisors) {
      if (multiply(d, P).isInfinity) return d;
    }
    return card;
  }

  List<ECPoint> getPoints() {
    List<ECPoint> points = [const ECPoint.infinity()];
    for (BigInt x = BigInt.zero; x < p; x += BigInt.one) {
      BigInt rhs = (x.pow(3) + a * x + b) % p;
      if (rhs < BigInt.zero) rhs += p;

      BigInt? y = sqrtModPrime(rhs, p);
      if (y != null) {
        BigInt y2 = (p - y) % p;
        // Mostrar siempre la raíz menor primero, para un listado estable.
        if (y > y2) {
          final BigInt tmp = y;
          y = y2;
          y2 = tmp;
        }
        points.add(ECPoint(x, y));
        if (y != y2) {
          points.add(ECPoint(x, y2));
        }
      }
    }
    return points;
  }
}

/// Orden de un punto dentro del grupo, y si genera el grupo completo.
class PointOrder {
  final ECPoint point;
  final BigInt order;
  final bool isGenerator;

  const PointOrder(this.point, this.order, this.isGenerator);
}

/// Calcula el orden de cada punto. Un punto es generador si su orden es #E.
List<PointOrder> computePointOrders(EllipticCurve curve, List<ECPoint> points) {
  final BigInt card = BigInt.from(points.length);
  return [
    for (final ECPoint pt in points)
      () {
        final BigInt order = curve.findOrder(pt, card);
        return PointOrder(pt, order, order == card);
      }(),
  ];
}

/// Algoritmo de Tonelli-Shanks: raíz cuadrada de n módulo el primo p.
/// Devuelve null si n no es un residuo cuadrático módulo p.
BigInt? sqrtModPrime(BigInt n, BigInt p) {
  n = n % p;
  if (n < BigInt.zero) n += p;
  if (n == BigInt.zero) return BigInt.zero;
  if (p == BigInt.two) return n;

  // Criterio de Euler
  if (n.modPow((p - BigInt.one) ~/ BigInt.two, p) != BigInt.one) {
    return null;
  }

  // p - 1 = Q · 2^S con Q impar
  BigInt Q = p - BigInt.one;
  int S = 0;
  while (Q.isEven) {
    Q ~/= BigInt.two;
    S++;
  }

  // p ≡ 3 (mod 4): atajo directo
  if (S == 1) {
    return n.modPow((p + BigInt.one) ~/ BigInt.from(4), p);
  }

  // Primer no-residuo cuadrático z
  BigInt z = BigInt.two;
  while (z.modPow((p - BigInt.one) ~/ BigInt.two, p) != p - BigInt.one) {
    z += BigInt.one;
  }

  int M = S;
  BigInt c = z.modPow(Q, p);
  BigInt t = n.modPow(Q, p);
  BigInt R = n.modPow((Q + BigInt.one) ~/ BigInt.two, p);

  while (t != BigInt.one) {
    // Menor i, con 0 < i < M, tal que t^(2^i) ≡ 1 (mod p)
    int i = 0;
    BigInt t2i = t;
    while (t2i != BigInt.one) {
      t2i = (t2i * t2i) % p;
      i++;
      if (i == M) return null; // inalcanzable si n es residuo cuadrático
    }

    // b = c^(2^(M-i-1)): son M-i-1 elevaciones al cuadrado, no 2^(M-i-1).
    BigInt b = c;
    for (int j = 0; j < M - i - 1; j++) {
      b = (b * b) % p;
    }

    M = i;
    c = (b * b) % p;
    t = (t * c) % p;
    R = (R * b) % p;
  }
  return R;
}
