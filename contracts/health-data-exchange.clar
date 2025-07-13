;; Anonymous Health Data Exchange Smart Contract
;; A decentralized platform for secure and anonymous health data sharing
;; Built on Stacks blockchain using Clarity

;; Define constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-invalid-data (err u104))
(define-constant err-insufficient-payment (err u105))
(define-constant err-expired (err u106))

;; Define data variables
(define-data-var platform-fee uint u50) ;; 0.5% fee
(define-data-var min-data-price uint u1000000) ;; 1 STX minimum
(define-data-var next-data-id uint u1)
(define-data-var next-request-id uint u1)
(define-data-var platform-enabled bool true)

;; Define data maps
(define-map health-data-registry
  { data-id: uint }
  {
    provider: principal,
    data-hash: (string-utf8 128),
    category: (string-utf8 50),
    price: uint,
    timestamp: uint,
    access-count: uint,
    is-active: bool,
    metadata: (string-utf8 256)
  }
)

(define-map data-access-permissions
  { data-id: uint, requester: principal }
  {
    granted: bool,
    timestamp: uint,
    expiry: uint,
    payment-amount: uint
  }
)

(define-map provider-profiles
  { provider: principal }
  {
    reputation-score: uint,
    total-data-shared: uint,
    total-earnings: uint,
    is-verified: bool,
    registration-timestamp: uint
  }
)

(define-map data-requests
  { request-id: uint }
  {
    requester: principal,
    category: (string-utf8 50),
    max-price: uint,
    description: (string-utf8 256),
    timestamp: uint,
            status: (string-ascii 20),
    matched-data-id: (optional uint)
  }
)

(define-map anonymization-keys
  { data-id: uint }
  {
    key-hash: (string-utf8 128),
    provider: principal,
    created-at: uint
  }
)

;; Provider registration function
(define-public (register-provider (metadata (string-utf8 256)))
  (let ((provider tx-sender))
    (asserts! (var-get platform-enabled) err-unauthorized)
    (asserts! (is-none (map-get? provider-profiles { provider: provider })) err-already-exists)
    (ok (map-set provider-profiles
      { provider: provider }
      {
        reputation-score: u100,
        total-data-shared: u0,
        total-earnings: u0,
        is-verified: false,
        registration-timestamp: block-height
      }
    ))
  )
)

;; Submit health data function
(define-public (submit-health-data 
  (data-hash (string-utf8 128))
  (category (string-utf8 50))
  (price uint)
  (metadata (string-utf8 256))
  (anonymization-key (string-utf8 128))
)
  (let (
    (data-id (var-get next-data-id))
    (provider tx-sender)
  )
    (asserts! (var-get platform-enabled) err-unauthorized)
    (asserts! (>= price (var-get min-data-price)) err-invalid-data)
    (asserts! (is-some (map-get? provider-profiles { provider: provider })) err-unauthorized)
    
    ;; Store data registry entry
    (map-set health-data-registry
      { data-id: data-id }
      {
        provider: provider,
        data-hash: data-hash,
        category: category,
        price: price,
        timestamp: block-height,
        access-count: u0,
        is-active: true,
        metadata: metadata
      }
    )
    
    ;; Store anonymization key
    (map-set anonymization-keys
      { data-id: data-id }
      {
        key-hash: anonymization-key,
        provider: provider,
        created-at: block-height
      }
    )
    
    ;; Update provider stats
    (match (map-get? provider-profiles { provider: provider })
      profile (map-set provider-profiles
        { provider: provider }
        (merge profile { total-data-shared: (+ (get total-data-shared profile) u1) })
      )
      false
    )
    
    ;; Increment data ID counter
    (var-set next-data-id (+ data-id u1))
    (ok data-id)
  )
)

;; Request data access function
(define-public (request-data-access (data-id uint) (duration uint))
  (let (
    (requester tx-sender)
    (data-entry (unwrap! (map-get? health-data-registry { data-id: data-id }) err-not-found))
    (price (get price data-entry))
    (platform-fee-amount (/ (* price (var-get platform-fee)) u10000))
    (provider-payment (- price platform-fee-amount))
  )
    (asserts! (var-get platform-enabled) err-unauthorized)
    (asserts! (get is-active data-entry) err-not-found)
    (asserts! (not (is-eq requester (get provider data-entry))) err-unauthorized)
    
    ;; Transfer payment to provider and platform
    (try! (stx-transfer? provider-payment requester (get provider data-entry)))
    (try! (stx-transfer? platform-fee-amount requester contract-owner))
    
    ;; Grant access permission
    (map-set data-access-permissions
      { data-id: data-id, requester: requester }
      {
        granted: true,
        timestamp: block-height,
        expiry: (+ block-height duration),
        payment-amount: price
      }
    )
    
    ;; Update data access count
    (map-set health-data-registry
      { data-id: data-id }
      (merge data-entry { access-count: (+ (get access-count data-entry) u1) })
    )
    
    ;; Update provider earnings
    (match (map-get? provider-profiles { provider: (get provider data-entry) })
      profile (map-set provider-profiles
        { provider: (get provider data-entry) }
        (merge profile { total-earnings: (+ (get total-earnings profile) provider-payment) })
      )
      false
    )
    
    (ok true)
  )
)

;; Create data request function
(define-public (create-data-request 
  (category (string-utf8 50))
  (max-price uint)
  (description (string-utf8 256))
)
  (let ((request-id (var-get next-request-id)))
    (asserts! (var-get platform-enabled) err-unauthorized)
    (asserts! (> max-price u0) err-invalid-data)
    
    (map-set data-requests
      { request-id: request-id }
      {
        requester: tx-sender,
        category: category,
        max-price: max-price,
        description: description,
        timestamp: block-height,
        status: "active",
        matched-data-id: (none uint)
      }
    )
    
    (var-set next-request-id (+ request-id u1))
    (ok request-id)
  )
)

;; Match data request function
(define-public (match-data-request (request-id uint) (data-id uint))
  (let (
    (request-entry (unwrap! (map-get? data-requests { request-id: request-id }) err-not-found))
    (data-entry (unwrap! (map-get? health-data-registry { data-id: data-id }) err-not-found))
  )
    (asserts! (var-get platform-enabled) err-unauthorized)
    (asserts! (is-eq tx-sender (get provider data-entry)) err-unauthorized)
    (asserts! (is-eq (get status request-entry) "active") err-invalid-data)
    (asserts! (<= (get price data-entry) (get max-price request-entry)) err-invalid-data)
    (asserts! (is-eq (get category data-entry) (get category request-entry)) err-invalid-data)
    
    ;; Update request status
    (map-set data-requests
      { request-id: request-id }
      (merge request-entry { 
        status: "matched",
        matched-data-id: (some data-id)
      })
    )
    
    (ok true)
  )
)

;; Verify provider function (only owner)
(define-public (verify-provider (provider principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (match (map-get? provider-profiles { provider: provider })
      profile (ok (map-set provider-profiles
        { provider: provider }
        (merge profile { is-verified: true })
      ))
      err-not-found
    )
  )
)

;; Update reputation score function (only owner)
(define-public (update-reputation (provider principal) (new-score uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-score u1000) err-invalid-data)
    (match (map-get? provider-profiles { provider: provider })
      profile (ok (map-set provider-profiles
        { provider: provider }
        (merge profile { reputation-score: new-score })
      ))
      err-not-found
    )
  )
)

;; Deactivate data function
(define-public (deactivate-data (data-id uint))
  (let ((data-entry (unwrap! (map-get? health-data-registry { data-id: data-id }) err-not-found)))
    (asserts! (is-eq tx-sender (get provider data-entry)) err-unauthorized)
    (ok (map-set health-data-registry
      { data-id: data-id }
      (merge data-entry { is-active: false })
    ))
  )
)

;; Read-only functions
(define-read-only (get-health-data (data-id uint))
  (map-get? health-data-registry { data-id: data-id })
)

(define-read-only (get-provider-profile (provider principal))
  (map-get? provider-profiles { provider: provider })
)

(define-read-only (get-data-access-permission (data-id uint) (requester principal))
  (map-get? data-access-permissions { data-id: data-id, requester: requester })
)

(define-read-only (get-data-request (request-id uint))
  (map-get? data-requests { request-id: request-id })
)

(define-read-only (has-valid-access (data-id uint) (requester principal))
  (match (map-get? data-access-permissions { data-id: data-id, requester: requester })
    permission (and 
      (get granted permission)
      (> (get expiry permission) block-height)
    )
    false
  )
)

(define-read-only (get-platform-stats)
  {
    total-data-entries: (var-get next-data-id),
    total-requests: (var-get next-request-id),
    platform-fee: (var-get platform-fee),
    min-data-price: (var-get min-data-price),
    platform-enabled: (var-get platform-enabled)
  }
)

;; Admin functions
(define-public (set-platform-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-fee u1000) err-invalid-data) ;; Max 10% fee
    (ok (var-set platform-fee new-fee))
  )
)

(define-public (set-min-data-price (new-price uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (var-set min-data-price new-price))
  )
)

(define-public (toggle-platform (enabled bool))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (var-set platform-enabled enabled))
  )
)

;; Emergency functions
(define-public (emergency-withdraw)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (as-contract (stx-transfer? (stx-get-balance tx-sender) tx-sender contract-owner))
  )
)