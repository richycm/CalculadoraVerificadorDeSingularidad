import 'dart:math';

/// Algoritmo Extendido de Euclides para inverso modular
BigInt modInverse(BigInt a, BigInt m) {
  BigInt m0 = m, t, q;
  BigInt x0 = BigInt.zero, x1 = BigInt.one;

  if (m == BigInt.one) return BigInt.zero;

  a = a % m;
  if (a < BigInt.zero) a += m;

  while (a > BigInt.one) {
    if (m == BigInt.zero) throw Exception("No tiene inverso modular");
    q = a ~/ m;
    t = m;
    m = a % m;
    a = t;
    t = x0;
    x0 = x1 - q * x0;
    x1 = t;
  }
  if (x1 < BigInt.zero) x1 += m0;
  return x1;
}

/// Test de primalidad de Miller-Rabin
bool isPrime(BigInt n, {int k = 5}) {
  if (n <= BigInt.one) return false;
  if (n == BigInt.two || n == BigInt.from(3)) return true;
  if (n % BigInt.two == BigInt.zero) return false;

  BigInt d = n - BigInt.one;
  int s = 0;
  while (d % BigInt.two == BigInt.zero) {
    d ~/= BigInt.two;
    s++;
  }

  final random = Random.secure();
  for (int i = 0; i < k; i++) {
    BigInt a = _randBigInt(BigInt.two, n - BigInt.two, random);
    BigInt x = a.modPow(d, n);
    if (x == BigInt.one || x == n - BigInt.one) continue;

    bool composite = true;
    for (int r = 1; r < s; r++) {
      x = x.modPow(BigInt.two, n);
      if (x == n - BigInt.one) {
        composite = false;
        break;
      }
    }
    if (composite) return false;
  }
  return true;
}

BigInt _randBigInt(BigInt min, BigInt max, Random random) {
  BigInt range = max - min;
  int bitLength = range.bitLength;
  BigInt res;
  do {
    String bits = '';
    for (int i = 0; i < bitLength; i++) {
      bits += random.nextBool() ? '1' : '0';
    }
    res = BigInt.parse(bits, radix: 2);
  } while (res > range);
  return res + min;
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
        points.add(ECPoint(x, y));
        BigInt y2 = (p - y) % p;
        if (y != y2) {
          points.add(ECPoint(x, y2));
        }
      }
    }
    return points;
  }
}

// Algoritmo de Tonelli-Shanks
BigInt? sqrtModPrime(BigInt n, BigInt p) {
  n = n % p;
  if (n < BigInt.zero) n += p;
  if (n == BigInt.zero) return BigInt.zero;
  if (p == BigInt.two) return n;

  // Euler's criterion
  if (n.modPow((p - BigInt.one) ~/ BigInt.two, p) != BigInt.one) {
    return null;
  }

  BigInt Q = p - BigInt.one;
  BigInt S = BigInt.zero;
  while (Q % BigInt.two == BigInt.zero) {
    Q ~/= BigInt.two;
    S += BigInt.one;
  }

  if (S == BigInt.one) {
    return n.modPow((p + BigInt.one) ~/ BigInt.from(4), p);
  }

  BigInt z = BigInt.two;
  while (z.modPow((p - BigInt.one) ~/ BigInt.two, p) != p - BigInt.one) {
    z += BigInt.one;
  }

  BigInt M = S;
  BigInt c = z.modPow(Q, p);
  BigInt t = n.modPow(Q, p);
  BigInt R = n.modPow((Q + BigInt.one) ~/ BigInt.two, p);

  while (true) {
    if (t == BigInt.zero) return BigInt.zero;
    if (t == BigInt.one) return R;

    BigInt t2i = t;
    BigInt i = BigInt.zero;
    for (i = BigInt.one; i < M; i += BigInt.one) {
      t2i = (t2i * t2i) % p;
      if (t2i == BigInt.one) break;
    }

    if (i == M) return null;

    BigInt b = c;
    BigInt pow2 = BigInt.one << (M - i - BigInt.one).toInt();
    for (int j = 0; j < pow2.toInt(); j++) {
      b = (b * b) % p;
    }

    M = i;
    c = (b * b) % p;
    t = (t * c) % p;
    R = (R * b) % p;
  }
}
