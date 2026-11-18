import java.nio.file.Files;
import java.nio.file.Path;
import java.security.KeyStore;
import java.security.MessageDigest;
import java.security.PrivateKey;
import java.security.SecureRandom;
import java.security.Signature;
import java.security.cert.X509Certificate;
import java.security.interfaces.RSAPublicKey;
import java.time.ZoneOffset;
import java.time.ZonedDateTime;
import java.util.Arrays;
import java.util.HexFormat;
import java.util.Locale;

/** Local custody proof only. Creates no APK and exports no key material. */
class SigningKeyProbe {
    public static void main(String[] args) {
        char[] password = null;
        boolean failed = false;
        try {
            if (args.length != 1 && args.length != 2) throw new IllegalArgumentException();
            String secret = System.getenv("TRAELYX_SIGNING_SETUP_PASSWORD");
            if (secret == null || secret.isEmpty()) throw new IllegalArgumentException();
            password = secret.toCharArray();
            KeyStore store = KeyStore.getInstance("PKCS12");
            try (var input = Files.newInputStream(Path.of(args[0]))) {
                store.load(input, password);
            }
            String alias = "traelyx-release";
            if (store.size() != 1 || !store.isKeyEntry(alias)) throw new IllegalArgumentException();
            var certificate = (X509Certificate) store.getCertificate(alias);
            certificate.checkValidity();
            if (certificate.getSubjectX500Principal().getName().toLowerCase(Locale.ROOT).contains("android debug")) {
                throw new IllegalArgumentException();
            }
            certificate.verify(certificate.getPublicKey());
            var publicKey = (RSAPublicKey) certificate.getPublicKey();
            int bits = publicKey.getModulus().bitLength();
            if (bits < 2048) throw new IllegalArgumentException();
            if (args.length == 2) {
                if (!args[1].equals("--initial") || bits != 4096 ||
                    !certificate.getNotAfter().toInstant().isAfter(
                        ZonedDateTime.now(ZoneOffset.UTC).plusYears(25).toInstant())) {
                    throw new IllegalArgumentException();
                }
            }
            var privateKey = (PrivateKey) store.getKey(alias, password);
            byte[] challenge = new byte[32];
            new SecureRandom().nextBytes(challenge);
            Signature proof = Signature.getInstance("SHA256withRSA");
            proof.initSign(privateKey);
            proof.update(challenge);
            byte[] signed = proof.sign();
            proof.initVerify(publicKey);
            proof.update(challenge);
            if (!proof.verify(signed)) throw new IllegalArgumentException();
            String digest = HexFormat.of().formatHex(
                MessageDigest.getInstance("SHA-256").digest(certificate.getEncoded()));
            System.out.println("{\"probe_version\":1,\"key_algorithm\":\"RSA\",\"key_bits\":" + bits +
                ",\"certificate_sha256\":\"" + digest + "\",\"not_before_utc\":\"" +
                certificate.getNotBefore().toInstant() + "\",\"not_after_utc\":\"" +
                certificate.getNotAfter().toInstant() + "\",\"private_key_proof_verified\":true}");
        } catch (Exception error) {
            System.err.println("Signing identity proof failed; details withheld.");
            failed = true;
        } finally {
            if (password != null) Arrays.fill(password, '\0');
        }
        if (failed) System.exit(1);
    }
}
