let secretNumber = 0;
let attempts = 0;
const maxAttempts = 5;
let gameOver = false;

function startNewGame() {
    secretNumber = Math.floor(Math.random() * 50) + 1;
    attempts = 0;
    gameOver = false;
    document.getElementById('gameContainer').style.display = 'block';
    document.getElementById('gameOver').classList.remove('show');
    document.getElementById('gameInfo').style.display = 'block';
    document.getElementById('feedback').classList.remove('show');
    document.getElementById('guessInput').value = '';
    document.getElementById('guessInput').focus();
    updateAttemptsDisplay();
}

function updateAttemptsDisplay() {
    document.getElementById('attemptsLeft').textContent = maxAttempts - attempts;
}

function submitGuess() {
    if (gameOver) return;

    const guessInput = document.getElementById('guessInput');
    const guess = parseInt(guessInput.value);

    if (!guessInput.value) {
        showFeedback('Please enter a number!', 'invalid');
        return;
    }

    if (isNaN(guess) || guess < 1 || guess > 50) {
        showFeedback('Please enter a number between 1 and 50!', 'invalid');
        guessInput.value = '';
        return;
    }

    attempts++;
    guessInput.value = '';

    if (guess === secretNumber) {
        showFeedback(`🎉 Correct! You found it in ${attempts} attempt(s)!`, 'correct');
        endGame(true);
    } else if (guess < secretNumber) {
        showFeedback(`📈 Too low! Try again.`, 'too-low');
        updateAttemptsDisplay();
    } else {
        showFeedback(`📉 Too high! Try again.`, 'too-high');
        updateAttemptsDisplay();
    }

    if (attempts >= maxAttempts && guess !== secretNumber) {
        showFeedback(`❌ Game Over! The secret number was ${secretNumber}`, 'invalid');
        endGame(false);
    }

    guessInput.focus();
}

function showFeedback(message, type) {
    const feedback = document.getElementById('feedback');
    feedback.textContent = message;
    feedback.className = `feedback show ${type}`;
}

function endGame(won) {
    gameOver = true;
    document.getElementById('gameContainer').style.display = 'none';
    document.getElementById('gameInfo').style.display = 'none';
    const gameOverDiv = document.getElementById('gameOver');
    gameOverDiv.classList.add('show');

    if (won) {
        gameOverDiv.classList.add('won');
        gameOverDiv.classList.remove('lost');
        document.getElementById('endEmoji').textContent = '🎉';
        document.getElementById('endMessage').textContent = 'Congratulations! You Won!';
    } else {
        gameOverDiv.classList.add('lost');
        gameOverDiv.classList.remove('won');
        document.getElementById('endEmoji').textContent = '❌';
        document.getElementById('endMessage').textContent = 'Game Over! Better Luck Next Time!';
    }

    document.getElementById('secretNumberDisplay').textContent = secretNumber;
    document.getElementById('attemptsUsed').textContent = attempts;
}

function resetGame() {
    startNewGame();
}

window.onload = function() {
    startNewGame();
    document.getElementById('guessInput').addEventListener('keypress', function(event) {
        if (event.key === 'Enter') {
            submitGuess();
        }
    });
};
