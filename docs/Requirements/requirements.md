# PayLink Project Requirements

## 1. Problem definition

PayLink lets customers pay utility bills (electricity, water, internet, mobile) from a digital wallet, through the app or an agent terminal.

PayLink holds customers' money and sits between the customer and the billers, so it must be correct with money even when things fail.

### Main problems

#### Unstable network
The mobile app sends the same payment twice because the network was slow, so a customer could be charged twice.

#### Slow or unavailable biller
A biller may take too long, refuse the payment, or reply late, so the payment outcome is unknown.

#### Concurrent payments
Two payments from one wallet at the same moment could make the balance negative.

#### Different biller formats
Each biller uses a different protocol (JSON, XML, async callbacks, batch files), so adding a biller must not break the others.

#### Failed notifications
An SMS or push message may fail, but the payment must still complete.

#### Differences with the biller's records
PayLink and the biller may disagree, so a daily reconciliation is needed.

### Goal
A backend that never double-charges, never goes negative, handles every failure with a defined outcome, and lets new billers be added easily.

## 2. Stakeholders

Customer, agent, admin, support employee, billers.

## 3. Technology choice

Java Spring Boot (declared in Phase 1 and fixed afterwards).

## 4. Hard cases

1. **Duplicate request (slow network):** related requirement FR-10 (idempotency key).
2. **ElectroCo takes 12 s to answer:** FR-13 (Unknown state and retries).
3. **AquaCo refuses with an error code:** FR-12, FR-22 (release hold, SMS with reason).
4. **Concurrent payments, balance covers only one:** NFR-1 (zero negative balances).
5. **SMS provider down:** FR-23 (3 retries, then undelivered).
6. **Duplicate TopUpNet callback:** FR-14.
7. **Settlement file mismatch:** FR-26 (reconciliation report).
8. **New biller added:** NFR-4 (modifiability).

## 5. Additional cases we identified

- **Rejected payments:** amount below 5 or above 10,000 EGP, insufficient funds, or daily limit reached (5,000 basic, 30,000 verified). FR-18
- **Velocity rule:** more than 5 payments in 60 seconds blocks the account for 10 minutes. FR-19
- **Blocked account** tries to pay. FR-21
- **Unknown payment resolves later:** re-queried after 1, 5 and 15 minutes. It is never refunded automatically.
- **AquaCo rejects an overpayment** (amount above the bill).
- **TopUpNet callback says "failed"**, not only "success".
- **Invalid state transition** is rejected. FR-11
- **Fee edge cases:** promotion gives a 0 fee, mobile top-up has a 1 EGP minimum, internet fee is tiered. FR-16
- **Agent payment:** 40% of the fee is credited as commission only when the payment completes. FR-17
- **Disabled biller** cannot be paid.

## 6. User stories

Priority uses MoSCoW (Must, Should, Could). FR numbers refer to the brief.

### Accounts and Wallet

#### US-1 Register (Must, FR-1)
**As a** customer, **I want** to register, **so that** I can use a wallet.
- **Given** I provide valid details, **when** I register, **then** an account and an empty wallet are created with the basic verification level.
- **Given** the phone number is already registered, **when** I register, **then** the request is rejected with a clear reason.

#### US-2 Upgrade verification (Should, FR-2)
**As a** customer, **I want** to be upgraded to verified, **so that** I get a higher daily limit.
- **Given** I am a basic customer, **when** support verifies me, **then** my daily limit changes from 5,000 EGP to 30,000 EGP.

#### US-3 View balance and history (Must, FR-3)
**As a** customer, **I want** to see my available balance, held balance and transaction history, **so that** I know where my money is.
- **Given** a payment is in FundsHeld, **when** I view my wallet, **then** the payment amount appears in the held balance and not in the available balance.
- **Given** I have past transactions, **when** I open the history, **then** each entry shows date, amount and status.

#### US-4 Top up the wallet (Must, FR-4)
**As a** customer, **I want** to top up my wallet by simulated card or agent cash, **so that** I have money to pay bills.
- **Given** a valid top-up of 500 EGP, **when** it succeeds, **then** my available balance increases by 500 EGP and a ledger entry is created.

#### US-5 Ledger entries (Must, FR-5)
**As the** system, **I want** every balance change to create a ledger entry, **so that** balances are always provable.
- **Given** any money movement (top-up, hold, charge, refund, commission), **when** it happens, **then** a ledger entry is written and the balance is computed from the ledger, never overwritten.

### Biller Catalog

#### US-6 Manage billers (Must, FR-6)
**As an** admin, **I want** to add, edit and disable billers and services, **so that** the catalog stays current.
- **Given** a new biller, **when** I add it with its required fields and min and max amounts, **then** it appears in the catalog.
- **Given** a biller is disabled, **when** a customer tries to pay it, **then** the payment is rejected with a clear reason.

#### US-7 Browse billers (Must, FR-7)
**As a** customer, **I want** to see the list of billers and the input fields each needs, **so that** I enter the right data.
- **Given** I select ElectroCo, **when** the screen opens, **then** it asks for the meter number.
- **Given** I select TopUpNet, **when** the screen opens, **then** it asks for the phone number.

### Payment Processing

#### US-8 Bill inquiry (Must, FR-8)
**As a** customer, **I want** to see the amount, fee and total before paying, **so that** there are no surprises.
- **Given** a valid meter number with a bill of 350.00 EGP, **when** I run an inquiry, **then** I see 350.00 amount, 2.50 fee and 352.50 total.
- **Given** an invalid meter number, **when** I run an inquiry, **then** I get a clear error.

#### US-9 Pay a bill (Must, FR-9)
**As a** customer, **I want** to pay a bill from my wallet, **so that** I don't have to queue.
- **Given** enough balance and passed fraud checks, **when** I confirm, **then** the total is held, the biller is called and, on confirmation, the payment is Completed.

#### US-10 No double charge (Must, FR-10)
**As a** customer, **I want** repeated requests with the same idempotency key to return the original result, **so that** a slow network never charges me twice.
- **Given** a payment with key K already processed, **when** the same key is sent again, **then** no second charge is made and the first result is returned.

#### US-11 Payment life cycle (Must, FR-11)
**As the** system, **I want** payments to follow only the allowed transitions, **so that** money is never in an inconsistent state.
- **Given** a payment in Completed, **when** an action tries to move it to Failed, **then** the transition is rejected and logged.

#### US-12 Hold and release funds (Must, FR-12)
**As a** customer, **I want** my money held before the biller is called and released if the payment fails, **so that** I never lose money on a failed payment.
- **Given** a payment moves to FundsHeld, **when** the biller refuses, **then** the payment becomes Failed, the hold is released and the payment becomes Refunded.

#### US-13 Timeout becomes Unknown (Must, FR-13)
**As a** customer, **I want** a clear message when the biller is slow, **so that** I know my payment is being processed.
- **Given** the biller doesn't answer within 10 seconds, **when** the timeout occurs, **then** the payment becomes Unknown, the money stays held, and I am told it is being processed.
- **Given** a payment is Unknown, **when** 1, 5 and 15 minutes pass, **then** the system re-queries the biller (up to 3 times) and then waits for reconciliation.
- **Given** a payment is Unknown, **when** it is retried, **then** it is never refunded automatically.

#### US-14 Resolve Unknown payments (Must)
**As the** system, **I want** to resolve an Unknown payment when the biller answers later, **so that** the outcome is correct.
- **Given** an Unknown payment, **when** the biller confirms, **then** it becomes Completed.
- **Given** an Unknown payment, **when** the biller refuses or reconciliation finds no payment, **then** it becomes Failed and the hold is released.

### Biller Integration

#### US-15 Async callbacks (Must, FR-14)
**As the** system, **I want** to accept TopUpNet callbacks and ignore duplicates, **so that** a payment completes only once.
- **Given** a TopUpNet callback "success", **when** it arrives, **then** the payment becomes Completed.
- **Given** the same callback arrives again, **when** it is received, **then** it is ignored and logged.
- **Given** a callback "failed" arrives, **when** it is received, **then** the payment becomes Failed and the hold is released.

#### US-16 Multiple biller formats (Must, FR-15)
**As the** business, **I want** ElectroCo (REST/JSON), AquaCo (XML) and TopUpNet (async) supported, **so that** customers can pay different utilities.
- **Given** a payment to each biller, **when** it is made, **then** the system uses that biller's own protocol and the customer sees the same result format.

#### US-17 Biller refusal (Must)
**As a** customer, **I want** a clear reason when a biller refuses, **so that** I know what to do.
- **Given** AquaCo rejects an amount above the bill, **when** the refusal arrives, **then** the payment becomes Failed, the hold is released and I get an SMS with the reason.

#### US-18 Biller outage isolation (Should)
**As a** customer, **I want** payments to other billers to keep working when one biller is down, **so that** one outage doesn't stop everything.
- **Given** ElectroCo is down, **when** I pay AquaCo, **then** the payment is processed normally.

#### US-19 Add a new biller easily (Should)
**As a** developer, **I want** to add a biller with only a new integration and configuration, **so that** existing modules stay unchanged.
- **Given** a new biller adapter and configuration, **when** it is deployed, **then** no existing module needs changes.

### Fees and Commissions

#### US-20 Fee calculation (Must, FR-16)
**As the** business, **I want** fees calculated by the rules, **so that** revenue is correct.
- **Given** electricity or water, **when** a fee is calculated, **then** it is 2.50 EGP.
- **Given** a mobile top-up, **when** a fee is calculated, **then** it is 1.5% of the amount with a minimum of 1 EGP.
- **Given** internet, **when** a fee is calculated, **then** it is 2 EGP up to 200 EGP and 4 EGP above.
- **Given** a promotion period for a chosen biller, **when** a fee is calculated, **then** it is 0.

#### US-21 Agent payments and commission (Should, FR-17)
**As an** agent, **I want** to pay on behalf of a customer and earn commission, **so that** I am paid for the service.
- **Given** a payment made at an agent terminal, **when** it completes, **then** 40% of the service fee is credited to the agent's wallet.
- **Given** the payment fails, **when** it is Failed, **then** no commission is credited.

### Fraud Checks

#### US-22 Payment limits (Must, FR-18)
**As the** business, **I want** payments outside the limits rejected with a clear reason, **so that** risk is controlled.
- **Given** an amount below 5 or above 10,000 EGP, **when** I pay, **then** the payment is Rejected with the reason.
- **Given** a basic account that would exceed 5,000 EGP today (30,000 for verified), **when** I pay, **then** the payment is Rejected with the reason.
- **Given** insufficient balance, **when** I pay, **then** the payment is Rejected.

#### US-23 Velocity rule (Should, FR-19)
**As the** business, **I want** fast repeated payments blocked, **so that** fraud is limited.
- **Given** more than 5 payments in 60 seconds from one account, **when** the next is sent, **then** the account is blocked for 10 minutes.

#### US-24 Concurrent payments (Must)
**As a** customer, **I want** my balance never to go negative, **so that** the system is safe.
- **Given** two payments at the same moment and a balance covering only one, **when** both arrive, **then** one succeeds, the other is Rejected, and the balance is never negative.

### Support and Admin

#### US-25 Search payments (Must, FR-20)
**As a** support employee, **I want** to search a payment by reference and see its full history, **so that** I can help customers.
- **Given** a payment reference, **when** I search, **then** I see every state change with time and reason.

#### US-26 Block and unblock accounts (Should, FR-21)
**As a** support employee, **I want** to block and unblock an account, **so that** I can stop suspicious activity.
- **Given** a blocked account, **when** its owner tries to pay, **then** the payment is Rejected.

#### US-27 Edit fees and limits (Should, FR-24)
**As an** admin, **I want** to edit fee and limit values without redeploying, **so that** changes are quick.
- **Given** I change the daily limit, **when** I save, **then** new payments use the new value without a restart.

#### US-28 Audit log (Must, FR-25)
**As an** admin, **I want** every money movement and admin action logged, **so that** everything can be traced.
- **Given** any money movement or admin action, **when** it happens, **then** an audit record stores who, when and why.

### Notifications

#### US-29 Notifications (Must, FR-22, FR-23)
**As a** customer, **I want** an SMS and a push message on completion and on failure, **so that** I know the result.
- **Given** a payment completes or fails, **when** it finishes, **then** I receive an SMS and a push message.
- **Given** the SMS provider is down, **when** a payment completes, **then** the payment still completes, the SMS is retried 3 times and finally marked undelivered.

### Reconciliation and extras

#### US-30 Reconciliation report (Should, FR-26)
**As a** support employee, **I want** a daily comparison with the biller's settlement file, **so that** differences are found.
- **Given** a settlement file lists a payment PayLink has as Failed, **when** reconciliation runs, **then** the difference is flagged in the report for support to review.

#### US-31 Refund a completed payment (Could, FR-27)
**As a** customer, **I want** to request a refund of a completed payment, **so that** I can recover money paid by mistake.
- **Given** a completed payment, **when** I request a refund, **then** support must approve before money is returned.

#### US-32 Daily totals (Could, FR-28)
**As an** admin, **I want** daily totals of payments, fees earned, commissions paid and failures per biller, **so that** I can follow the business.
- **Given** a day has ended, **when** I open the report, **then** the totals are shown per biller.

## 7. Non-functional requirements

Each requirement has a target we can measure with a test or a pipeline report.

#### NFR-1 Correctness
Zero double charges and zero negative balances in the duplicate-request test (hard case 1) and the concurrent-payment test (hard case 4).
**Measured by:** automated tests; the build fails if any wallet balance is below 0 or any payment is charged twice.

#### NFR-2 Performance
The system sustains 100 payments per second for 1 minute against the mock billers.
**Measured by:** a load test reporting throughput and error rate.

#### NFR-3 Resilience
When one biller is down or slow, payments to the other billers still succeed (0 failures caused by the outage).
**Measured by:** an automated test with one mock biller set to fail while the others are called.

#### NFR-4 Modifiability
Adding a new biller changes only the Biller Integration module and configuration (0 changes in other modules).
**Measured by:** hard case 8, checking the list of changed files in the pull request.

#### NFR-5 Auditability
100% of money movements have an audit record with who, when and why.
**Measured by:** a test that compares the count of ledger entries with audit records.

#### NFR-6 Testability
At least 70% line coverage on domain logic.
**Measured by:** the JaCoCo coverage report published by the CI pipeline.

#### NFR-7 Response time
95% of bill inquiries return in under 5 seconds when the biller answers normally, and a payment stops waiting for a live biller after 10 seconds.
**Measured by:** load and timeout tests.

#### NFR-8 Deployability
`docker compose up` starts the application, database and mock billers from a clean clone, and the pipeline deploys the stack locally on every push to `main`.
**Measured by:** a fresh-clone test and the pipeline deployment log.

## 8. Questions, ambiguities and decisions

### 8.1 Ambiguities found in the brief and our decisions

#### D-1 Is the service fee refunded when a payment fails?
**Decision:** yes. The whole held amount (bill plus fee) is released. Fee income is credited only when the payment completes.
**Reason:** the hold covers the total, and PayLink earns nothing from a failed payment.

#### D-2 Can a customer cancel while a payment is Unknown?
**Decision:** no. The customer waits for the biller's answer, a retry or reconciliation.
**Reason:** the biller may have received the payment, and cancelling could lose money for the customer or PayLink.

#### D-3 What if the same idempotency key arrives while the first request is still processing?
**Decision:** no second payment is created. The system returns the current status of the original payment.
**Reason:** guarantees one payment, one charge (hard case 1).

#### D-4 Do held (not yet completed) payments count towards the daily limit?
**Decision:** yes. Completed, FundsHeld, SentToBiller and Unknown payments count. Rejected, Failed and Refunded do not.
**Reason:** otherwise a customer could exceed the limit by sending several payments at once.

#### D-5 Do the 5 and 10,000 EGP limits apply to the bill amount or to the total with fee?
**Decision:** the bill amount, without the fee.
**Reason:** the limit check is step 1 of the payment flow, before the fee is added.

#### D-6 Does the velocity rule count rejected attempts? Is the 6th payment itself allowed?
**Decision:** all payment attempts count. The 6th payment in 60 seconds is rejected and the account is blocked for 10 minutes.
**Reason:** matches "more than 5 payments in 60 seconds is blocked".

#### D-7 Who pays when an agent pays on behalf of a customer?
**Decision:** the customer's wallet is charged. The agent earns 40% of the service fee as commission, which comes out of PayLink's fee and is not an extra charge.
**Reason:** the brief says commission is part of the fee income.

#### D-8 What happens to an Unknown payment after the 3 retries (1, 5 and 15 minutes)?
**Decision:** it stays Unknown and the money stays held until reconciliation. If the settlement file lists it, it becomes Completed; if not, Failed.
**Reason:** matches section 2.5 of the brief: Unknown is never refunded automatically.

#### D-9 How long is an idempotency key remembered, and what is its scope?
**Decision:** the key is unique per customer and stored for at least 24 hours.
**Reason:** covers slow networks and retries without storing keys forever.

#### D-10 Which rounding mode for money?
**Decision:** BigDecimal with 2 decimals, `HALF_UP`. Never double or float.
**Reason:** the brief requires exact decimals but does not name the rounding mode.

#### D-11 Is the NetCo batch biller required?
**Decision:** not in the first version. It is optional in the brief and is built only if time remains.
**Reason:** FR-15 requires 3 billers: ElectroCo, AquaCo and TopUpNet.

#### D-12 Which target for bill inquiry time (NFR-7)?
**Decision:** 95% of inquiries in under 5 seconds (changed from 3).
**Reason:** AquaCo takes 2 to 4 seconds, so 3 seconds could fail on normal water-bill inquiries.

#### D-13 Which notifications are sent?
**Decision:** SMS and push on completion and failure. Email is optional.
**Reason:** FR-22 requires SMS and push.

#### D-14 Should refunds of completed payments (FR-27) be in scope?
**Decision:** Could. Only if time remains, with support approval.
**Reason:** the priority is Could in the brief.

### 8.2 Questions we asked the AI

- **Question:**    what problems should the problem definition cover?
  **AI answer:**   from the situations and hard cases from the brief.
  **What we did:** fixed, we wanted to gather all info and then write them in our style.

- **Question:**    which hard cases need extra user stories?
  **AI answer:**   gathered from all the functional requirements and did user stories for them. 
  **What we did:** fixed, its 3-second inquiry target was wrong for AquaCo (2 to 4 s), so we changed it to 5s.

- **Question:**    what non-functional requirements should we measure?
  **AI answer:**   from the hard cases, it suggested many solutions and test
  **What we did:** accepted, i shared the brief to ai, so it covered everything the brief wanted us to cover.

