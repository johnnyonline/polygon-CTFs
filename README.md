# polygon-CTFs
Polygon Labs ethDenver CTFs

## How to play
1. Clone the repository
2. Install Docker
3. build the Docker image with `docker build -t polygon-ctfs .`
4. run the Docker container with `docker run -it --rm -v "/${PWD}:/polygon-ctfs" polygon-ctfs bash`
5. Code your solution in the `Attacker.sol` file (inside each challenge's folder in the test folder)
6. Run the challenge with `forge test --mt ChallengeNameChallenge`. If the test is executed successfully, you've passed!
