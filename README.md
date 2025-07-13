# Anonymous Health Data Exchange

A decentralized platform for secure and anonymous health data sharing built on the Stacks blockchain using Clarity smart contracts.

## Features

- **Anonymous Data Sharing**: Secure sharing of health data while maintaining privacy
- **Provider Registration**: Healthcare providers can register and build reputation
- **Data Monetization**: Providers can set prices for their data
- **Access Control**: Granular permissions for data access
- **Request Matching**: Automated matching of data requests with available data
- **Reputation System**: Trust-based system for data providers
- **Platform Fees**: Sustainable revenue model for platform maintenance

## Smart Contract Functions

### Core Functions
- `register-provider`: Register as a healthcare data provider
- `submit-health-data`: Submit anonymized health data for sharing
- `request-data-access`: Request access to specific health data
- `create-data-request`: Create a request for specific types of data
- `match-data-request`: Match requests with available data

### Admin Functions
- `verify-provider`: Verify provider credentials (owner only)
- `update-reputation`: Update provider reputation score
- `set-platform-fee`: Adjust platform fees
- `toggle-platform`: Enable/disable platform operations

### Read-Only Functions
- `get-health-data`: Retrieve data entry details
- `get-provider-profile`: Get provider information
- `get-data-access-permission`: Check access permissions
- `has-valid-access`: Verify if access is still valid
- `get-platform-stats`: Get platform statistics

## Technical Specifications

- **Blockchain**: Stacks
- **Language**: Clarity
- **Max Contract Size**: 300 lines
- **Data Storage**: On-chain metadata, off-chain actual data
- **Privacy**: Anonymization keys for data protection

## Security Features

- Provider verification system
- Time-based access expiration
- Payment-based access control
- Reputation-based trust system
- Emergency withdrawal mechanisms

## Getting Started

1. Install Clarinet CLI
2. Clone this repository
3. Run `clarinet check` to validate the contract
4. Run `clarinet test` to execute tests
5. Deploy using `clarinet deploy`

## License

MIT License - see LICENSE file for details