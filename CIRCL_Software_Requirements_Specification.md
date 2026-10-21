# Software Requirements Specification (SRS)
## Project: CIRCL – Smart Community Platform for Resource Sharing and Microservices

---

### Document Information
- **Project Name:** CIRCL
- **Document Version:** 1.0.0
- **Date:** July 15, 2026
- **Status:** Final Baseline
- **Author:** Software Engineering Team

---

15: ## Table of Contents
16: 1. [Introduction](#1-introduction)
17:    - 1.1 Purpose
18:    - 1.2 Scope
19:    - 1.3 Definitions, Acronyms, and Abbreviations
20: 2. [Overall Description](#2-overall-description)
21:    - 2.1 Product Perspective
22:    - 2.2 Product Functions
23:    - 2.3 User Characteristics
24:    - 2.4 Assumptions and Dependencies
25: 3. [External Interface Requirements](#3-external-interface-requirements)
26:    - 3.1 User Interfaces
27:    - 3.2 Hardware Interfaces
28:    - 3.3 Software Interfaces
29: 4. [Functional Requirements](#4-functional-requirements)
30:    - FR1: Authentication, Registration & Access Control
31:    - FR2: User Profiles, Gamification & Verification
32:    - FR3: Resource Request Creation & Discovery
33:    - FR4: Transactions, Negotiation & Escrow
34:    - FR5: Real-Time Communication
35:    - FR6: Ratings, Community & Moderation
36:    - FR7: System Preferences & Ecosystem
37: 5. [Non-Functional Requirements](#5-non-functional-requirements)

...

196: ## 4. Functional Requirements
197: 
198: ### FR1: Authentication, Registration & Access Control
199: - **FR1.1: Email Registration & OTP Verification:** The system shall allow users to register with an email and password, requiring account activation via a 4-digit OTP.
200: - **FR1.2: Google OAuth Authentication:** The system shall allow users to sign up and log in via Google OAuth, automatically creating a profile if one does not exist.
201: - **FR1.3: Credential Complexity & Uniqueness:** The system shall enforce password complexity rules (8–15 characters, mixed case, numbers, symbols) and validate username uniqueness in real time.
202: - **FR1.4: Mandatory Terms & Safety Acknowledgement:** The system shall require users to accept the Terms of Conditions and Safety Guidelines before completing registration.
203: - **FR1.5: Login & Session Persistence:** The system shall authenticate users via email/password and provide a "Remember Me" toggle for session persistence.
204: - **FR1.6: Biometric Authentication Setup:** The system shall allow users to enable Face ID or device biometrics to authorize secure actions like payments.
205: - **FR1.7: Password Recovery:** The system shall allow users to reset forgotten passwords via a secure email recovery link.
206: - **FR1.8: Role-Based Routing:** The system shall check user roles upon login, routing administrative users to the Admin Dashboard and regular users to the Feed Screen.
207: - **FR1.9: Secure Logout:** The system shall allow users to securely log out and clear locally stored authentication tokens.
208: 
209: ### FR2: User Profiles, Gamification & Verification
210: - **FR2.1: Automatic Profile Provisioning:** The system shall create a default profile upon registration, initializing username, location, avatar, Circl Points (0), and Aura Level (Bronze).
211: - **FR2.2: Profile Management:** The system shall allow users to update display names, locations, contact info, and inventory lists.
212: - **FR2.3: Onboarding & Profile NIC Verification:** The system shall prompt first-time users with a National Identity Card (NIC) verification step via secure hashing, allowing them to skip it during onboarding and complete it later in their profile settings.
213: - **FR2.4: Verification Badge Display:** The system shall display a verification badge on profiles and request cards for NIC-verified users.
214: - **FR2.5: Circl Points Award System:** The system shall automatically award Circl Points to users upon completing transactions.
215: - **FR2.6: Aura Level Progression & Display:** The system shall automatically upgrade a user's Aura Level (Bronze, Silver, Gold, Diamond) as their Circl Points reach defined mathematical thresholds, and visually display this tier on their avatar.
216: 
217: ### FR3: Resource Request Creation & Discovery
218: - **FR3.1: Multi-Type Request Creation:** The system shall allow users to create four request types: Free Borrow, Paid Rent, Free Favour, and Paid Task.
219: - **FR3.2: Guided Creation Workflow:** The system shall guide users through a multi-step request creation process covering task details, location preferences, and a final review.
220: - **FR3.3: Dynamic Financial & Duration Inputs:** The system shall dynamically display input fields for expected duration, budget limits, and security deposits based on the selected request type.
221: - **FR3.4: Location Preferences & GPS Detection:** The system shall allow users to specify execution preferences (In-Person, Flexible, or Remote) and auto-detect coordinates using device GPS.
222: - **FR3.5: Address Autocomplete & Saved Locations:** The system shall provide real-time address autocomplete suggestions and allow users to save frequently used locations.
223: - **FR3.6: Request Lifecycle & Expiration:** The system shall allow users to edit or cancel open requests, automatically expiring unaccepted requests after 7 days.
224: - **FR3.7: Feed & Dynamic Filtering:** The system shall display open requests in a scrollable feed with real-time filters for type, distance, and price.
225: - **FR3.8: Keyword Search Engine:** The system shall provide a search bar to query open requests by matching keywords in titles and descriptions.
226: - **FR3.9: Interactive Map Display:** The system shall display an interactive map with colour-coded markers representing different request types.
227: - **FR3.10: Intelligent Matching Algorithm:** The system shall rank requests using a compatibility score based on spatial proximity, user ratings, and Circl Points, highlighting the best match.
228: 
229: ### FR4: Transactions, Negotiation & Escrow
230: - **FR4.1: Request Acceptance & Transaction Setup:** The system shall allow users to accept open requests, changing status to "In Progress" and creating a transaction record.
231: - **FR4.2: Payment Gateway Integration:** The system shall integrate a payment gateway to facilitate secure payments, including simulated escrow holds for Rent and Paid Task requests.
232: - **FR4.3: Mutual Transaction Completion:** The system shall require both transaction parties to independently confirm completion before finalizing the exchange and releasing escrowed funds.
233: - **FR4.4: Dispute Management:** The system shall allow users to flag transactions for dispute, freezing simulated deposits, ratings, and points until an administrator resolves it via the Admin Dashboard.
234: 
235: ### FR5: Real-Time Communication
236: - **FR5.1: Chat Hub Management:** The system shall provide a centralized chat inbox allowing users to search, filter (Unread, Active, Completed), and sort conversations.
237: - **FR5.2: Real-Time Peer-to-Peer Chat:** The system shall open a private, real-time messaging channel between users during negotiation and active transaction phases.
238: - **FR5.3: Rich Media Attachments:** The system shall allow users to securely transmit images and documents (PDF/Word) within the chat interface.
239: - **FR5.4: Automated System Messaging:** The system shall automatically inject contextual system events into the chat feed (e.g., "Payment completed", "Terms accepted", "Cancellation requested").
240: - **FR5.5: In-App Notification Engine:** The system shall send real-time in-app notifications for incoming messages, request acceptances, and transaction status updates.
241: 
242: ### FR6: Ratings, Community & Moderation
243: - **FR6.1: Post-Transaction Ratings & Reviews:** The system shall prompt both parties to submit a 1-to-5 star rating and optional text review upon transaction completion.
244: - **FR6.2: Automated Rating Aggregation:** The system shall automatically recalculate and update user average ratings and review counts upon new submissions.
245: - **FR6.3: User Moderation & Reporting:** The system shall allow users to report other profiles for spam, harassment, or suspicious activity.
246: 
247: ### FR7: System Preferences & Ecosystem
248: - **FR7.1: Multi-Language Support:** The system shall support real-time dynamic language switching between Tamil, Sinhala, and English.
249: - **FR7.2: Theme Adaptability:** The system shall support Light and Dark themes, adapting dynamically to device settings.
250: - **FR7.3: Companion Web Portal Integration:** The system shall provide a companion website displaying app features, platform info, and Android APK downloads.
251: 
252: ---

## 5. Non-Functional Requirements

### 5.1 Performance Requirements
- **Response Latency:** Database query response times and REST API operations shall execute within 2 seconds under standard 4G network conditions.
- **Real-Time Latency:** Chat message transmission via WebSocket channels shall achieve end-to-end delivery within 500 milliseconds.
- **Map Rendering:** The interactive map interface shall render 100 localized map markers smoothly at 60 FPS without UI frame stutter.

### 5.2 Security Requirements
- **Data Encryption in Transit:** All communications between client devices and Supabase BaaS or third-party APIs shall be encrypted using TLS 1.3 protocol over HTTPS/WSS.
- **Row-Level Security (RLS):** Backend database tables shall enforce strict PostgreSQL RLS policies to restrict read/write access based on session authenticated UUIDs.
- **Sensitive Data Hashing:** National Identity Card numbers shall never be stored in plain text; they shall be processed into salted SHA-512 digest hashes prior to DB persistence.
- **Secure On-Device Storage:** Local session credentials and app lock PIN codes shall be stored using hardware-backed keychains via `flutter_secure_storage`.

### 5.3 Usability Requirements
- **UI Design System:** Interface elements shall strictly adhere to dark theme glassmorphism guidelines utilizing modern typography (Google SNPro / Ogelo) with high contrast compliance.
- **Ease of Access:** Primary user workflows (creating a request, accepting an offer, entering chat) shall require no more than 3 screen interactions from the main dashboard.
- **Localization Support:** The System shall accommodate localized string bundles (`l10n.yaml`) for internationalization readiness.

### 5.4 Reliability, Availability & Maintainability
- **System Uptime:** The cloud database backend (Supabase Infrastructure) shall maintain 99.9% operational availability.
- **Graceful Fault Handling:** Mobile application shall gracefully recover from transient network disconnections, caching un-sent chat messages locally until connection restoration.
- **Database Backup:** Daily automated PostgreSQL database snapshots shall be maintained with point-in-time recovery (PITR) enabled.

---

## 6. System Requirements

### 6.1 Hardware Requirements

#### Client Mobile Device (Minimum Specifications)
- **Processor:** Quad-Core 1.8 GHz ARM64 Processor.
- **RAM:** Minimum 3 GB RAM (4 GB recommended for smooth map caching).
- **Storage:** 150 MB free internal disk space.
- **Peripherals:** Integrated Camera (5 MP minimum) and GPS sensor.

#### Host Infrastructure / Server Environment (Cloud Instance)
- **Provider:** Managed Cloud BaaS (Supabase Cloud).
- **CPU / Compute:** Multi-core virtualized database nodes.
- **RAM:** Minimum 4 GB DB instance RAM.
- **Storage:** High IOPS SSD Storage.

### 6.2 Software Requirements
- **Operating Systems (Mobile Clients):** Android 8.0 (API Level 26) or higher / iOS 13.0 or higher.
- **Operating Systems (Development & Admin):** Windows 10/11, macOS Sequoia, or Linux Ubuntu 22.04 LTS.
- **Database Engine:** PostgreSQL 15+ with PostGIS extensions (managed via Supabase).

### 6.3 Tools & Technologies Stack

| Layer | Technology / Tool | Version / Details |
| :--- | :--- | :--- |
| **Frontend Framework** | Flutter SDK | ^3.11.0 (Dart SDK) |
| **Backend Service** | Supabase Cloud | PostgreSQL 15, Auth, Realtime Engine |
| **State Management** | Provider | ^6.1.5+1 |
| **Payment Gateway** | PayHere Mobile SDK | ^3.2.3 |
| **Geospatial & Mapping** | Google Maps Flutter & Geolocator | `google_maps_flutter` ^2.11.0, `geolocator` ^14.0.3 |
| **Machine Learning / OCR** | Google ML Kit Text Recognition | `google_mlkit_text_recognition` ^0.15.1 |
| **Document Scanner** | Cunning Document Scanner | ^2.5.0 |
| **Local Security** | Flutter Secure Storage & Local Auth | `flutter_secure_storage` ^10.3.1, `local_auth` ^3.0.1 |
| **Cryptography** | Crypto Package | ^3.0.3 (SHA-512 Hashing) |
| **Development IDEs** | VS Code / Android Studio | Equipped with Flutter Extension plugins |

---

## 7. Use Case Analysis & UML Diagrams

### 7.1 System Use Case Diagram (UML)

```mermaid
usecaseDiagram
    actor CommunityUser as "Community User\n(Requester / Provider)"
    actor Admin as "Platform Admin\n/ Moderator"
    actor PayHere as "PayHere Gateway"
    actor MLKit as "Google ML Kit OCR"

    package "CIRCL Platform Ecosystem" {
        usecase UC1 as "UC1: Register & Authenticate"
        usecase UC2 as "UC2: Verify NIC Identity"
        usecase UC3 as "UC3: Create Resource Request / Listing"
        usecase UC4 as "UC4: Explore Listings via Map Feed"
        usecase UC5 as "UC5: Negotiate Offer & Accept Request"
        usecase UC6 as "UC6: Process Payment & Escrow Hold"
        usecase UC7 as "UC7: Chat & Coordinate Handover"
        usecase UC8 as "UC8: Submit Review & Accumulate Aura"
        usecase UC9 as "UC9: Raise Transaction Dispute"
        usecase UC10 as "UC10: Arbitrate Dispute & Manage Escrow"
        usecase UC11 as "UC11: Manual NIC Review & User Moderation"
    }

    CommunityUser --> UC1
    CommunityUser --> UC2
    CommunityUser --> UC3
    CommunityUser --> UC4
    CommunityUser --> UC5
    CommunityUser --> UC6
    CommunityUser --> UC7
    CommunityUser --> UC8
    CommunityUser --> UC9

    UC2 .> MLKit : <<include>>
    UC6 .> PayHere : <<include>>

    Admin --> UC10
    Admin --> UC11
```

---

### 7.2 Detailed Use Case Specifications

#### Use Case 1 (UC1): Post a Resource / Service Request
- **Use Case ID:** UC1
- **Use Case Name:** Create Resource Request or Listing
- **Primary Actor:** Community User (Requester / Lender)
- **Preconditions:** User must be logged in with an active account status.
- **Trigger:** User taps the floating "+" action button on the home feed.
- **Main Success Scenario:**
  1. User selects listing classification: Resource (Borrow/Rent) or Service (Favour/Gig).
  2. User enters item title, detailed description, category, and target location.
  3. User specifies pricing structure (Free Goodwill vs. Monetized Rate & Deposit).
  4. User attaches photos captured via device camera or gallery.
  5. User submits the post form.
  6. System validates fields, uploads images to Supabase Storage, and writes record to `requests` table with `status = 'open'`.
  7. System renders success confirmation and displays post in active feed and map.
- **Alternative Flow:**
  - *4a. Missing required fields:* System displays inline validation error and highlights incomplete inputs.
  - *6a. Network failure during upload:* System catches storage exception and prompts user to retry submission.
- **Postconditions:** Request becomes visible to all nearby users in feed and Google Maps view.

---

#### Use Case 2 (UC2): Accept Request & Complete Escrow Transaction
- **Use Case ID:** UC2
- **Use Case Name:** Accept Request and Escrow Payment Settlement
- **Primary Actor:** Community Provider / Borrower
- **Secondary Actor:** PayHere Payment Gateway Engine
- **Preconditions:** User is logged in, NIC verified, and viewing an open listing posted by another user.
- **Trigger:** Provider taps "Accept / Offer" on listing detail page.
- **Main Success Scenario:**
  1. Provider proposes offer price and safety deposit amount.
  2. Requester receives offer alert in real-time chat and clicks "Accept Offer".
  3. System initiates transaction entry in `transactions` table and updates `requests` status to `negotiating`.
  4. Borrower proceeds to payment checkout screen.
  5. System calculates total charges (Rental Rate + Escrow Security Deposit Hold + 4% Platform Fee).
  6. System invokes PayHere SDK checkout dialog.
  7. User completes card authorization successfully.
  8. PayHere callback triggers system to register payment record and place deposit in safety escrow table.
  9. System updates transaction status to `in_progress`.
- **Alternative Flow:**
  - *7a. Payment Decline:* PayHere returns error status. System retains transaction in `negotiating` state and alerts user to re-attempt payment with valid payment card.
- **Postconditions:** Funds are safely held in escrow, transaction transitions to active fulfillment phase, and chat displays confirmed handover timeline.

---

#### Use Case 3 (UC3): Verify Identity via NIC OCR Engine
- **Use Case ID:** UC3
- **Use Case Name:** Perform Automated NIC Identity Scanning
- **Primary Actor:** Community User
- **Secondary Actor:** Google ML Kit Text Recognition Engine
- **Preconditions:** User navigates to Identity Verification screen.
- **Trigger:** User taps "Scan National Identity Card".
- **Main Success Scenario:**
  1. User positions NIC document inside camera scanner frame.
  2. Cunning Document Scanner captures high-resolution document image buffer.
  3. App passes buffer to Google ML Kit OCR engine for text processing.
  4. System parses extracted alphanumeric string to isolate identity card number.
  5. System generates salted SHA-512 cryptographic hash digest of the NIC string.
  6. System calls backend `check_duplicate_nic` RPC function.
  7. System confirms hash is unique, creates entry in `nic_verifications` table, uploads encrypted photo, and flags profile as `verified`.
- **Alternative Flow:**
  - *6a. Duplicate Hash Detected:* System rejects request, warning user that the provided NIC is already linked to an existing account.
  - *4a. Unclear Image Scan:* System alerts user that document text could not be parsed and prompts retake or manual submission for admin queue review.
- **Postconditions:** User profile receives verified badge, unlocking high-tier high-deposit transactions.

---

#### Use Case 4 (UC4): Arbitrate Dispute & Escrow Resolution (Admin)
- **Use Case ID:** UC4
- **Use Case Name:** Arbitrate Transaction Dispute
- **Primary Actor:** Platform Admin / Moderator
- **Preconditions:** Active transaction flagged with status `disputed` by a user.
- **Trigger:** Admin selects case row from Admin Dispute Dashboard.
- **Main Success Scenario:**
  1. Admin inspects dispute details, uploaded photographic evidence, and chat history log.
  2. Admin determines resolution: Deposit Refund to Borrower OR Deposit Forfeiture to Lender.
  3. Admin executes decision action button on dashboard panel.
  4. System triggers ledger RPC routine to update transaction status to `resolved`.
  5. System releases escrow funds to designated party minus fee structure.
  6. System dispatches real-time notification alerts to both transacting parties.
- **Postconditions:** Dispute is marked resolved, financial ledger is closed, and frozen escrow funds are fully disbursed.

---

## 8. Constraints & Future Enhancements

### 8.1 System Constraints
1. **Third-Party API Dependency:** Platform functionality relies on external service readiness (Google Maps API, Supabase Infrastructure, and PayHere Payment Gateway).
2. **Network Dependency:** Mobile application requires active Internet connectivity; offline capabilities are constrained to cached feed reads and localized draft state.
3. **Platform Constraints:** Flutter mobile build targets are optimized for mobile touch devices (iOS & Android); desktop web rendering is restricted to administrative control workflows.
4. **Regulatory & Financial Compliance:** Payment processing must conform strictly to Sri Lankan monetary regulatory mandates enforced by Central Bank PayHere APIs.

### 8.2 Future Enhancements Roadmap
1. **Smart Contract Proof of Return:** Integration of immutable blockchain ledger logs for tracking item ownership and condition receipts upon check-in/check-out.
2. **AI-Powered Fair Price & Deposit Recommender:** Machine learning model trained on historical local transaction data to automatically recommend optimal rental prices and safety deposits.
3. **Hyper-Local Neighborhood Hubs (Circles):** Creation of micro-gated neighborhood circles allowing gated communities or universities to form private sharing sub-ecosystems.
4. **Peer-to-Peer Delivery Dispatch Integration:** Inclusion of automated courier dispatch triggers to deliver borrowed heavy equipment via integrated local delivery partners.

---
*End of Software Requirements Specification (SRS) Document for CIRCL Platform.*
