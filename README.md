# SkillForge

A decentralized skill verification and mentorship platform built on the Stacks blockchain.

## Overview

SkillForge is a comprehensive platform that enables skill verification, mentorship, and professional development through blockchain technology. It combines NFTs, governance mechanisms, and reputation systems to create a trustless environment for skill development and verification.

## Core Features

### Skill Management
- Create and verify skills with detailed metadata
- Experience-based leveling system
- Endorsement mechanism from qualified mentors
- Cooldown periods between level-ups
- Achievement tracking

### Mentorship System
- Stake-based mentor registration (1 STX required)
- Specialization tracking
- Performance metrics
- Student management
- Earnings tracking
- Reputation system

### Badge System
- Time-limited NFT badges
- Requirement-based issuance
- Revocation capability
- Holder tracking
- Expiration management

### Achievement System
- Custom achievement creation
- Rarity levels
- Points system
- Progress tracking
- Holder verification

### Governance
- Community proposal submission
- Democratic voting system
- Minimum vote thresholds
- Automated proposal execution
- Voting period management

## Technical Details

### Smart Contract Functions

#### Skill Management
```clarity
;; Create a new skill
(contract-call? .skillforge create-skill "Web Development" "Full stack development" u1)

;; Verify a skill
(contract-call? .skillforge verify-skill u1)

;; Level up a skill
(contract-call? .skillforge level-up-skill u1)
```

#### Mentor Operations
```clarity
;; Register as a mentor
(contract-call? .skillforge register-mentor)

;; Endorse a skill
(contract-call? .skillforge endorse-skill u1)
```

#### Badge Management
```clarity
;; Create a badge
(contract-call? .skillforge create-badge "Expert" "Expert level achievement" none (list u1))
```

#### Governance
```clarity
;; Submit a proposal
(contract-call? .skillforge submit-proposal "New Feature" "Add new feature X" u100)

;; Vote on a proposal
(contract-call? .skillforge vote-on-proposal u1 true)
```

## Security Features

- Stake requirements for mentors
- Cooldown periods for level-ups
- Minimum endorsement requirements
- Authorization checks
- Input validation
- Error handling

## Data Structures

### Skills
- Name and description
- Level and experience
- Verification status
- Owner and mentor
- Endorsements
- Achievements

### Mentors
- Active status
- Skills verified
- Reputation score
- Stake amount
- Specializations
- Success rate
- Student list
- Earnings

### Badges
- Name and description
- Issuer information
- Expiration date
- Requirements
- Holder list

## Query Functions

- `get-full-skill-details`: Complete skill information
- `get-mentor-performance`: Mentor metrics
- `get-achievement-statistics`: Achievement data
- `validate-badge`: Badge verification

## Error Handling

The contract includes comprehensive error handling with specific error codes for different scenarios:

- ERR-NOT-AUTHORIZED (u100)
- ERR-INVALID-SKILL (u101)
- ERR-ALREADY-VERIFIED (u102)
- ERR-NOT-MENTOR (u103)
- And more...

## Getting Started

1. Install Clarinet CLI
2. Clone the repository
3. Run `clarinet console`
4. Deploy the contract
5. Interact using the provided function calls

## Best Practices

- Always verify transaction success
- Check error codes in responses
- Monitor cooldown periods
- Verify badge expiration
- Review proposal details before voting
