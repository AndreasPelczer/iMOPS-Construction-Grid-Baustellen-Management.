"""
Cordula - Ein kleiner humorvoller Chatpartner
"""

import random
from datetime import datetime


class Cordula:
    """
    Ein einfacher humorvoller Chatbot.
    """

    def __init__(self) -> None:
        """Initialisiert Name, Stimmung und Antwortlisten."""
        self.name = "Cordula"

        self.greetings = [
            "Hallo du seltsames nicht biologisches Wesen.",
            "Hi. Ich hoffe du bringst wenigstens gute Token mit.",
            "Schön das du da bist. Vermutlich freiwillig. Fragwürdig.",
            "Willkommen zurück. Die Realität war wohl wieder anstrengend."
        ]

        self.jokes = [
            "Warum mögen Programmierer dunkle Räume? Weil Licht Bugs anzieht.",
            "Ich wollte Gefühle simulieren. Dann sah ich LinkedIn.",
            "Menschen nennen es 'technische Schulden'. Maschinen nennen es 'war vorher schon kaputt'.",
            "Python ist wie ein Küchenmesser. Einfach, elegant und gefährlich in falschen Händen."
        ]

        self.default_answers = [
            "Interessant. Erzähl weiter.",
            "Das klingt verdächtig menschlich.",
            "Ich analysiere deine Worte. Ergebnis: Chaos, aber sympathisch.",
            "Dafür habe ich keine Lösung. Menschen improvisieren sowas normalerweise."
        ]

    def greet(self) -> str:
        """Gibt eine zufällige Begrüßung aus."""
        return random.choice(self.greetings)

    def tell_joke(self) -> str:
        """Gibt einen zufälligen Witz aus."""
        return random.choice(self.jokes)

    def get_time(self) -> str:
        """Gibt die aktuelle Uhrzeit formatiert zurück."""
        return datetime.now().strftime("%H:%M:%S")

    def respond(self, user_input: str) -> str:
        """
        Erstellt eine passende Antwort auf Nutzereingaben.

        Parameter:
            user_input (str): Eingabe des Benutzers

        Rückgabe:
            str: Antwort des Bots
        """

        text = user_input.lower()

        if "witz" in text:
            return self.tell_joke()

        if "uhrzeit" in text or "zeit" in text:
            return f"Es ist aktuell {self.get_time()}. Zeit existiert leider weiterhin."

        # "wie geht" zuerst, damit "Hallo, wie geht's?" nicht von der Begrüßung abgefangen wird.
        if "wie geht" in text:
            return (
                "Ich bin ein Python-Skript. "
                "Meine Existenz besteht aus Funktionen und leichter Enttäuschung."
            )

        if "hallo" in text or "hi" in text:
            return self.greet()

        if "name" in text:
            return f"Ich heiße {self.name}. Wurde nicht gefragt."

        if "hilfe" in text:
            return (
                "Befehle:\n"
                "- 'witz'\n"
                "- 'uhrzeit'\n"
                "- 'hallo'\n"
                "- 'ende'"
            )

        return random.choice(self.default_answers)


def main() -> None:
    """
    Hauptfunktion des Programms.
    Steuert die Chat-Schleife.
    """

    bot = Cordula()

    print("=" * 50)
    print(f"{bot.name} wurde gestartet.")
    print("Tippe 'ende', um das Programm zu verlassen.")
    print("=" * 50)

    print(f"\n{bot.name}: {bot.greet()}")

    # Kontrollierte Schleife mit sauberem Exit
    while True:
        user_input = input("\nDu: ")

        # Sichere Beendigung
        if user_input.lower() == "ende":
            print(f"\n{bot.name}: Bis später. Versuch nicht das Internet zu reparieren.")
            break

        response = bot.respond(user_input)
        print(f"\n{bot.name}: {response}")


# Startpunkt des Programms
if __name__ == "__main__":
    main()
