#!/usr/bin/env bash
set -e

########################################
#  NO SAFETY. NO CHECKS. NO MERCY.
########################################

echo "[YOLO] Java Project Renamer – UNSAFE MODE"

read -rp "NEW PACKAGE (e.g. com.company.app): " NEW_PACKAGE
read -rp "NEW APP NAME (e.g. my-app): " NEW_APP

if [[ -z "$NEW_PACKAGE" || -z "$NEW_APP" ]]; then
  echo "[YOLO] Missing input. Coward detected."
  exit 1
fi

PKG_PATH="app/src/main/java/${NEW_PACKAGE//./\/}"
TEST_PKG_PATH="app/src/test/java/${NEW_PACKAGE//./\/}"

echo "[YOLO] Nuking existing Java sources…"
rm -rf app/src/main/java/*
rm -rf app/src/test/java/*

echo "[YOLO] Recreating package structure…"
mkdir -p "$PKG_PATH"
mkdir -p "$TEST_PKG_PATH"

########################################
#  FORCE CREATE MAIN CLASS
########################################
cat > "$PKG_PATH/App.java" <<EOF
package $NEW_PACKAGE;

public class App {
    public static void main(String[] args) {
        System.out.println("🔥 $NEW_APP is alive 🔥");
    }
}
EOF

########################################
#  FORCE CREATE TEST
########################################
cat > "$TEST_PKG_PATH/AppTest.java" <<EOF
package $NEW_PACKAGE;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.assertTrue;

public class AppTest {
    @Test
    void smokeTest() {
        assertTrue(true);
    }
}
EOF

########################################
#  BRUTE FORCE STRING REPLACEMENT
########################################
echo "[YOLO] Rewriting Gradle config…"
sed -i 's|rootProject.name = ".*"|rootProject.name = "'"$NEW_APP"'"|' settings.gradle.kts || true
sed -i 's|mainClass = ".*"|mainClass = "'"$NEW_PACKAGE"'.App"|' app/build.gradle.kts || true
sed -i 's|Main-Class".*|Main-Class"] = "'"$NEW_PACKAGE"'.App"|' app/build.gradle.kts || true

########################################
#  DOCKER – BLIND REWRITE
########################################
if [[ -f docker-compose.yml ]]; then
  sed -i 's|image:.*|image: '"$NEW_APP"'-app|' docker-compose.yml || true
fi

########################################
#  README – SMASH IT
########################################
if [[ -f README.md ]]; then
  sed -i "1s|.*|# $NEW_APP|" README.md || true
fi

########################################
#  PURGE ALL BUILD ARTIFACTS
########################################
echo "[YOLO] Purging caches and builds…"
rm -rf .gradle
rm -rf app/.gradle
rm -rf app/build

########################################
#  DONE
########################################
echo
echo "🔥🔥🔥 YOLO RENAME COMPLETE 🔥🔥🔥"
echo
echo "Package : $NEW_PACKAGE"
echo "App     : $NEW_APP"
echo
echo "Next:"
echo "  ./gradlew clean build"
echo "  docker-compose up --build"
echo
echo "If this broke something, that was the point."

