;; ALL-IN-ONE STX CONTRACT: DAO + NFT Membership + Vault + Proposals
;; + Investment Pool + Cross-chain Registry + Bounties + Staking
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Define the NFT trait interface
(define-trait nft-trait
  (
    (get-owner (uint) (response principal uint))
    (transfer (uint principal principal) (response bool uint))
    (get-token-uri (uint) (response (optional (string-ascii 256)) uint))
  )
)
(define-constant NFT-CONTRACT 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.nft-membership)

(define-constant DAO-TREASURY 'SP000000000000000000002Q6VF78.pox)
(define-constant MIN-VOTE-TOKENS u5000)
(define-constant CONTRACT-OWNER tx-sender)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; STATE
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-data-var vault-balance uint u0)
(define-data-var proposal-counter uint u0)

(define-map roles principal (string-ascii 16)) ;; founder, guardian, member, investor
(define-map votes uint {votes: (list 10 principal)})

(define-map proposals
  uint
  {
    proposer: principal,
    action: (string-ascii 50),
    description: (string-ascii 200),
    target: (optional principal),
    amount: uint,
    approved: bool,
    executed: bool
  }
)

(define-map registry
  (string-ascii 40)
  {
    chain: (string-ascii 20),
    owner: principal,
    info: (string-ascii 100)
  }
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ROLE MANAGEMENT
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-data-var valid-roles (list 4 (string-ascii 16)) (list "founder" "guardian" "member" "investor"))

(define-read-only (is-valid-role (role (string-ascii 16)))
  (is-some (index-of? (var-get valid-roles) role)))

(define-public (set-role (user principal) (role (string-ascii 16)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) (err u100))
    (asserts! (is-valid-role role) (err u101))
    (map-set roles user role)
    (ok true)
  )
)

(define-read-only (get-role (user principal))
  (ok (default-to "none" (map-get? roles user)))
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; NFT MEMBERSHIP VALIDATION
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Reference the NFT contract in the same deployment
(define-constant MEMBERSHIP-CONTRACT 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.membership)

;; NFT MEMBERSHIP VALIDATION
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; MEMBERSHIP VALIDATION
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-read-only (is-member (token-id uint))
  (ok (is-eq (unwrap-panic (get-role tx-sender)) "member")))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; VAULT & STAKING
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-public (deposit-vault)
  (let ((balance (stx-get-balance tx-sender)))
    (begin
      (asserts! (> balance u0) (err u102))
      (try! (stx-transfer? balance tx-sender (as-contract tx-sender)))
      (var-set vault-balance (+ (var-get vault-balance) balance))
      (ok true)
    )
  )
)

(define-read-only (vault-status)
  (ok (var-get vault-balance))
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; PROPOSAL SYSTEM
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-public (create-proposal 
    (action (string-ascii 50))
    (description (string-ascii 200))
    (target (optional principal))
    (amount uint))
  (let 
    ((id (+ (var-get proposal-counter) u1))
     (new-proposal {
       proposer: tx-sender,
       action: action,
       description: description,
       target: target,
       amount: amount,
       approved: false,
       executed: false
     }))
    (begin
      (asserts! (> amount u0) (err u400))
      (var-set proposal-counter id)
      (map-set proposals id new-proposal)
      (ok id)
    )
  )
)

(define-public (vote-proposal (id uint))
  (match (map-get? proposals id)
    proposal
      (let ((vote-record (default-to {votes: (list)} (map-get? votes id))))
        (asserts! (not (is-eq (len (get votes vote-record)) u10)) (err u200))
        (asserts! (not (is-some (index-of? (get votes vote-record) tx-sender))) (err u201))
        (let ((updated-votes (unwrap! (as-max-len? (append (get votes vote-record) tx-sender) u10) (err u202))))
          (map-set votes id {votes: updated-votes})
          (if (>= (len updated-votes) u3)
            (begin
              (map-set proposals id (merge proposal { approved: true }))
              (ok true)
            )
            (ok false)
          )
        )
      )
    (err u203)
  )
)

(define-public (execute-proposal (id uint))
  (match (map-get? proposals id)
    proposal
      (begin
        (asserts! (get approved proposal) (err u202))
        (asserts! (not (get executed proposal)) (err u203))
        (match (get target proposal)
          some-target
            (begin
              (try! (stx-transfer? (get amount proposal) (as-contract tx-sender) some-target))
              (map-set proposals id (merge proposal { executed: true }))
              (ok true)
            )
          (err u204)
        )
      )
    (err u205)
  )
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; CROSS-CHAIN ASSET REGISTRY
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-public (register-asset 
    (name (string-ascii 40))
    (chain (string-ascii 20))
    (info (string-ascii 100)))
  (let ((asset-data { chain: chain, owner: tx-sender, info: info }))
    (begin
      (asserts! (is-none (map-get? registry name)) (err u300))
      (map-set registry name asset-data)
      (ok true)
    )
  )
)

(define-read-only (get-asset (name (string-ascii 40)))
  (ok (map-get? registry name))
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; EMERGENCY GUARDIAN FUNCTION
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-constant MIN-WITHDRAW u1000)
(define-constant MAX-WITHDRAW u1000000)
(define-constant WITHDRAWAL-ERR (err u402))

(define-public (guardian-emergency-withdraw (amount uint) (recipient principal))
  (let 
    ((transfer-data {
      amount: (if (and (>= amount MIN-WITHDRAW) (<= amount MAX-WITHDRAW)) 
                  amount 
                  u0),
      sender: tx-sender,
      recipient: recipient
    }))
    (begin
      (asserts! (is-eq (unwrap! (get-role tx-sender) (err u401)) "guardian") (err u400))
      (asserts! (> (get amount transfer-data) u0) WITHDRAWAL-ERR)
      (as-contract (stx-transfer? 
        (get amount transfer-data) 
        (get sender transfer-data) 
        (get recipient transfer-data)))
    )
  )
)
