# Contributing Guide

Thank you for considering contributing to AutoDecrypt! This guide outlines the contribution process to help you get started.

## How to Contribute

### 1. Fork the Repository

1. Navigate to the [AutoDecrypt repository](https://github.com/yourusername/autodecrypt).
2. Click on the **Fork** button in the upper right corner to create your copy of the repository.

### 2. Clone Your Fork

```bash
# Clone your forked repository
git clone https://github.com/yourusername/autodecrypt.git
cd autodecrypt
```

### 3. Create a New Branch

```bash
# Create a new branch for your feature/fix
git checkout -b feature/my-new-feature
```

**Branch Naming Conventions:**
- Feature branches: `feature/description`
- Bugfix branches: `bugfix/description`
- Documentation branches: `docs/update-description`

### 4. Make Changes

- Implement your feature or fix.
- Follow coding style and best practices.
- Write clear and detailed commit messages.

### 5. Test Your Changes

Run the provided tests to ensure nothing is broken:

```bash
# Run the test suite
./test-suite.sh
```

### 6. Commit Your Changes

```bash
# Add and commit your changes
git add .
git commit -m "Add feature X"
```

### 7. Push to Your Fork

```bash
# Push changes to your forked repository
git push origin feature/my-new-feature
```

### 8. Submit a Pull Request

1. Go to the original [AutoDecrypt repository](https://github.com/yourusername/autodecrypt)
2. Click on **Pull Requests** and start a new pull request.
3. Provide a descriptive title and detailed explanation of your changes.
4. Submit the pull request for review.

## Code of Conduct

Please adhere to the [Code of Conduct](CODE_OF_CONDUCT.md) to maintain a respectful and supportive community.

## Style Guide

1. Follow existing code style and naming conventions.
2. Document your code with comments where necessary.
3. Keep commits focused and descriptive.
4. Write documentation for new features.
5. Update tests when adding new features or fixing bugs.
