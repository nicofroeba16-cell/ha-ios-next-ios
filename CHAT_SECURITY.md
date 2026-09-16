# Flüchtiger Ende-zu-Ende-Chat

## Sicherheitsmodell

- Jedes Gerät besitzt getrennte X25519- und Ed25519-Schlüssel im iOS-Schlüsselbund.
- Für jeden Nachrichtenblock wird ein frischer flüchtiger X25519-Schlüssel erzeugt.
- Der gemeinsame Schlüssel wird per HKDF-SHA-256 abgeleitet; der Inhalt wird mit ChaCha20-Poly1305 verschlüsselt.
- Jede vollständige Envelope inklusive Absender, Empfänger, Medientyp und Blockposition wird mit Ed25519 signiert.
- Bereits bekannte Kontaktschlüssel werden lokal angeheftet. Ein Schlüsselwechsel blockiert den Versand, bis er bewusst geklärt wurde.
- Die angezeigten Sicherheitsnummern müssen über einen zweiten vertrauenswürdigen Kanal verglichen werden. Der aktuelle Ansatz ist TOFU mit manueller Verifikation und kein Double-Ratchet-/Signal-Protokoll.

## Keine Nachrichtenablage

- Die iOS-App hält Nachrichten und entschlüsselte Medien nur im Arbeitsspeicher. Nach App-Neustart ist der Verlauf weg.
- `URLSessionConfiguration.ephemeral` verhindert URL-Cache, Cookies und persistente Netzwerk-Caches für den Chat.
- Der Relay legt Nachrichten oder Medien nie in SQLite oder Dateien ab.
- Der Relay hält ausschließlich verschlüsselte Blöcke in einem begrenzten RAM-Puffer: maximal 120 Sekunden, Delete-on-Delivery, maximal 128 MiB insgesamt und 48 MiB pro Zielgerät.
- Ist ein Empfänger zu lange offline, geht die Nachricht absichtlich verloren. Das ist der Preis der No-Storage-Garantie.
- Öffentliche Geräteschlüssel werden persistent gespeichert. Der Relay sieht außerdem notwendige Metadaten wie Gerätekennungen, Zeit, Größe und Medientyp.

## Medien

- Text: maximal 16 KiB.
- Bilder: lokale Skalierung auf maximal 2.560 Pixel und JPEG-Komprimierung, maximal 12 MiB.
- Voice: unkomprimiertes Mono-WAV direkt aus `AVAudioEngine`, vollständig im RAM, maximal 24 MiB.
- Video: Import und Wiedergabe aus RAM, maximal 30 MiB.
- Inhalte werden in 384-KiB-Blöcke geteilt; jeder Block wird separat verschlüsselt und signiert.

## Transport und Fernzugriff

Die Ende-zu-Ende-Verschlüsselung schützt Inhalte unabhängig vom Transport. Für Erreichbarkeit außerhalb des Heimnetzes soll der Relay trotzdem ausschließlich über ein authentifiziertes VPN und HTTPS erreichbar sein. Home Assistant, Runner und Adminservice dürfen nicht als ungeschützte HTTP-Dienste ins Internet gestellt werden.

Eine App-Installation darf unter iOS nicht stillschweigend einen VPN-Tunnel aktivieren. Unterstützte Betriebswege:

1. Ein von der App eingerichtetes Personal VPN mit einmaliger Systemfreigabe und anschließendem On-Demand-Regelsatz.
2. Ein per MDM installiertes VPN-Profil für vollständig verwaltete Geräte.
3. Ein separat verwaltetes WireGuard-/Tailscale-VPN; die App nutzt dessen private DNS-Namen.

WireGuard ist als Packet Tunnel implementiert. Die App akzeptiert nur einen engen `wg-quick`-Teilumfang, blockiert Skriptanweisungen, speichert die private Konfiguration als this-device-only Keychain-Eintrag und übergibt der Extension nur eine persistente Referenz. Für die Endabnahme fehlen noch die konkrete Serverkonfiguration, Apples Network-Extension-Freigabe/Signierung, die einmalige iOS-Systemzustimmung und der Test auf echter Hardware.


## Owner-Tickets sind kein Chatverlauf

Support-/Admin-Anfragen anderer Benutzer laufen über einen bewusst getrennten Ticketkanal:

- GET /v1/chat/session liefert die serverseitig aufgelöste Rolle owner oder member.
- POST /v1/chat/tickets erstellt als authentifizierter Chat-Benutzer ein Ticket.
- Tickets werden persistent in der Admin-SQLite-Datenbank gespeichert und sind deshalb ausdrücklich nicht Teil der No-Storage-Garantie des E2EE-Chats.
- Ein Chat-Token darf die Owner-Ticket-Inbox nicht lesen und kann keine Owner-Antwort auf fremde Tickets schreiben.
- Lesen, Antworten und Statusänderungen in der Owner-Inbox erfordern den getrennten Owner-Token; die iOS-App hält diesen weiterhin im Schlüsselbund und öffnet Owner Control erst nach Face ID.
- Tickettexte dürfen keine Passwörter, Tokens, privaten Schlüssel oder andere Secrets enthalten.
