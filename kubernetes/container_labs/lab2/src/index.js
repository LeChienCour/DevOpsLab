import './styles/main.scss';

class App {
    constructor() {
        this.counter = 0;
        this.currentTheme = 'light';
        this.init();
    }

    init() {
        this.setupEventListeners();
        this.updateBuildInfo();
        this.startAnimation();
    }

    setupEventListeners() {
        const colorBtn = document.getElementById('colorBtn');
        const counterBtn = document.getElementById('counterBtn');

        colorBtn.addEventListener('click', () => this.toggleTheme());
        counterBtn.addEventListener('click', () => this.incrementCounter());
    }

    toggleTheme() {
        this.currentTheme = this.currentTheme === 'light' ? 'dark' : 'light';
        document.body.classList.toggle('dark-theme');
        
        // Add visual feedback
        const btn = document.getElementById('colorBtn');
        btn.textContent = `Switch to ${this.currentTheme === 'light' ? 'Dark' : 'Light'} Theme`;
    }

    incrementCounter() {
        this.counter++;
        document.getElementById('counter').textContent = this.counter;
        
        // Add animation
        const counterSpan = document.getElementById('counter');
        counterSpan.classList.add('pulse');
        setTimeout(() => counterSpan.classList.remove('pulse'), 300);
    }

    updateBuildInfo() {
        const buildTime = new Date().toLocaleString();
        document.getElementById('buildTime').textContent = buildTime;
        
        // Simulate environment detection
        const isDev = process.env.NODE_ENV === 'development';
        document.getElementById('environment').textContent = isDev ? 'Development' : 'Production';
    }

    startAnimation() {
        const cards = document.querySelectorAll('.feature-card');
        cards.forEach((card, index) => {
            setTimeout(() => {
                card.classList.add('animate-in');
            }, index * 200);
        });
    }
}

// Initialize the app when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    new App();
});

// Add some build-time information
console.log('🐳 Multistage Docker Lab App initialized');
console.log('Build timestamp:', new Date().toISOString()); 