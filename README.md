# Bon your Friends

iPhone-App zum Aufteilen von Kassenzetteln. Bon scannen, jede Zeile als Karte wischen: rechts ist deins, links nicht deins, nach oben geteilt. Bei Mehrfachpackungen stellst du mit dem Regler ein, wie viele davon deine waren.

Alles läuft auf dem iPhone. Die Texterkennung macht Apples Vision, die Produktnamen räumt Apples eingebaute KI (Foundation Models) auf. Es gibt keinen Server, keinen API-Schlüssel und die Fotos verlassen das Handy nicht.

Voraussetzungen: iPhone 15 Pro oder neuer mit iOS 26 und eingeschalteter Apple Intelligence. Ohne Apple Intelligence funktioniert die App trotzdem, dann bleiben die Namen so abgekürzt wie auf dem Bon.

## App bekommen

Jeder Push auf `main` baut die App auf GitHub. Die fertige Datei liegt unter **Actions**, beim neuesten grünen Lauf ganz unten bei **Artifacts** als `BonYourFriends-ipa`. Herunterladen und entpacken, darin ist `BonYourFriends.ipa`.

## Aufs iPhone installieren (Sideloadly)

1. Sideloadly nur von sideloadly.io herunterladen und auf dem Computer installieren. Unter Windows zusätzlich iTunes und iCloud von Apples Webseite (nicht aus dem Microsoft Store).
2. iPhone per Kabel anschließen und dem Computer vertrauen.
3. Auf dem iPhone den Entwicklermodus einschalten: Einstellungen, Datenschutz & Sicherheit, Entwicklermodus. Das iPhone startet neu.
4. In Sideloadly die `BonYourFriends.ipa` hineinziehen, deine Apple-ID eintragen (am besten eine zweite, nur dafür angelegte) und auf Start klicken.
5. Auf dem iPhone: Einstellungen, Allgemein, VPN & Geräteverwaltung, deine Apple-ID antippen und vertrauen.

Mit einer kostenlosen Apple-ID läuft die App 7 Tage. Danach in Sideloadly einfach nochmal installieren, oder dort die automatische Auffrischung einschalten.
