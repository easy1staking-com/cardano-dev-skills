# GovTool Software Architecture Documentation

**Valid as of: 2024-04-30**

## Overview

This documentation outlines the software architecture of the GovTool project.
GovTool is the decentralized application composed of a React frontend,
Haskell backend connected to db-sync, and a Node.js
utility backend that serves validation of the governance actions metadata.

## Frontend

# Technology Stack

- [React](https://react.dev/): The library for web user interfaces.
- [Vite](https://vitejs.dev/): The build tool for modern web development.
- [TypeScript](https://www.typescriptlang.org/): The language for static typing.
- [@mui](https://mui.com/): The library for React components.
- [react-query](https://tanstack.com/query/latest): The library for data fetching.
- [react-router](https://reactrouter.com/): The library for routing.
- [cardano-serialization-lib](https://github.com/Emurgo/cardano-serialization-lib): The library for serialization and deserialization of Cardano data structures.

# Description

Frontend is a React application using Vite as a built tool to enhance development speed and optimize production builds. Frontend interacts with the backend service via REST API and with the Cardano blockchain via cardano-serialization-lib and connected supported wallets (for the list of compatible wallets go [here](https://docs.gov.tools/cardano-govtool/using-govtool/getting-started/compatible-wallets)).

# Components

- **Direct voter** - direct voter is a DRep which does not have a metadata and have all the ADA delegated to themselves. This component combines the registration and delegation process into one step. Direct voters are not visible in the DRep directory.
  Direct voters ui components are (no specific file names are provided as they might be continuosly updated):

  - Direct voter registration card - UI component visible on the dashboard allowing to navigate to the Direct voter registration form. It displays current Direct voter status and amount of ADA.
  - Direct voter registration form - UI component allowing to register as a Direct voter and delegate all the ADA to themselves. Under the hood metadata anchor is mocked with provided default values.
    Direct voter uses following CSL services:
  - TransactionBuilder - to build the transaction
  - CertificatesBuilder - to build the delegation certificate
  - DRepRegistration - to build the DRep registration certificate

- **DRep** - DRep is a Decentralized Representative which has a metadata and can delegate ADA to other DReps. DRep registration and delegation are separate processes. DReps are visible in the DRep directory.

  DRep ui components are (no specific file names are provided as they might be continuosly updated):

  - DRep registration card - UI component visible on the dashboard allowing to navigate to the DRep registration form. It displays current DRep status and amount of ADA.
  - DRep registration form - UI component allowing to register as a DRep. Under the hood metadata anchor is mocked with provided default values.
    DRep uses following CSL services:
  - TransactionBuilder - to build the transaction
  - CertificatesBuilder - to build the DRep registration certificate
  - DRepRegistration - to build the DRep registration certificate
  - DRepDeregistration - to build the DRep deregistration certificate
  - DRepUpdate - to build the DRep update certificate

**Note**

- Sole Voter can become a DRep by providing the metadata.
- DRep can become a Sole Voter by delegating the ADA to themselves.

- **DRep directory** - DRep directory is a list of all registered DReps. It displays DRep metadata, and amount of Voting Power. DRep directory is visible for all users. DRep directory is the part of delegation pillar.

  DRep directory allows to delegate ADA to DReps. It uses following CSL services:

  - Credential
  - DRep
  - Certificate
  - VoteDelegation

- **GA Submission** - GA Submission is a form allowing to submit a Governance Action. GA Submission is the part of governance pillar. GA Submission uses following CSL services:

  - TransactionBuilder - to build the transaction
  - CertificatesBuilder - to build the governance action certificate
  - GovernanceAction - to build the governance action certificate

  Additionaly, GA Submission uses Metadata validation service to validate the metadata.

## Backend

# Technology Stack

- [Haskell](https://www.haskell.org/): An advanced, purely functional programming language.
- [cardano-node](https://github.com/IntersectMBO/cardano-node): The core component that is used to participate in a Cardano decentralised blockchain.
- [cardano-db-sync](https://github.com/IntersectMBO/cardano-db-sync): A component that follows the Cardano chain and stores blocks and transactions in PostgreSQL.

# Description

The backend of our application is built using Haskell, a purely functional programming language known for its strong static typing, high-level abstractions, and expressive syntax.

Our backend interacts with the Cardano blockchain through two main components: `cardano-node` and `cardano-db-sync`.

# Components

- **Cardano Node**

The `cardano-node` is the core component that our backend uses to participate in the Cardano decentralized blockchain. It allows our application to create transactions, submit them to the network, and listen for new blocks and transactions.

- **Cardano DB-Sync**

The `cardano-db-sync` component follows the Cardano chain and stores blocks and transactions in a PostgreSQL database. This allows our application to query blockchain data in a structured and efficient manner.

## Application Logic

The application logic is implemented in Haskell. It handles requests from the frontend, reads from the DB-Sync, and sends responses back to the frontend.

## Data Storage

Our application uses PostgreSQL for data storage. The `cardano-db-sync` component populates the database with blockchain data, and our application logic also stores additional data as needed, such as governance actions.

## Architecture diagram

**Valid as of: 2024-06-06**
![Architecture diagram](<Architecture diagram.png>)
