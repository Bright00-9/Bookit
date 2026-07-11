import random

def play_game():
    """Simple number guessing game with if-else logic."""
    secret_number = random.randint(1, 10)
    attempts = 0
    max_attempts = 3

    print("🎮 Welcome to the Number Guessing Game!")
    print(f"I'm thinking of a number between 1 and 10. You have {max_attempts} attempts.\n")

    while attempts < max_attempts:
        try:
            guess = int(input("Enter your guess: "))
            attempts += 1

            if guess < 1 or guess > 10:
                print("Please enter a number between 1 and 10!\n")
                attempts -= 1
                continue

            if guess == secret_number:
                print(f"🎉 Correct! You found it in {attempts} attempt(s)!")
                return True
            elif guess < secret_number:
                print(f"📈 Too low! Try again. Attempts left: {max_attempts - attempts}\n")
            else:
                print(f"📉 Too high! Try again. Attempts left: {max_attempts - attempts}\n")

        except ValueError:
            print("Invalid input! Please enter a number.\n")
            attempts -= 1

    print(f"❌ Game Over! The secret number was {secret_number}")
    return False

if __name__ == "__main__":
    play_game()
    
    while True:
        play_again = input("\nDo you want to play again? (yes/no): ").lower()
        if play_again == "yes" or play_again == "y":
            play_game()
        elif play_again == "no" or play_again == "n":
            print("Thanks for playing! Goodbye!")
            break
        else:
            print("Please enter 'yes' or 'no'")

        