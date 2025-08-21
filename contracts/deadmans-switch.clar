(define-constant contract-owner tx-sender)

(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INSUFFICIENT_BALANCE (err u103))
(define-constant ERR_STILL_ACTIVE (err u104))
(define-constant ERR_INVALID_TIMEOUT (err u105))
(define-constant ERR_INVALID_AMOUNT (err u106))

(define-constant MIN_TIMEOUT_BLOCKS u144)
(define-constant MAX_TIMEOUT_BLOCKS u52560)

(define-map switches
    { owner: principal }
    {
        beneficiary: principal,
        balance: uint,
        last-checkin: uint,
        timeout-blocks: uint,
        created-at: uint
    }
)

(define-map switch-exists { owner: principal } bool)

(define-data-var total-switches uint u0)
(define-data-var total-value-locked uint u0)

(define-public (create-switch (beneficiary principal) (timeout-blocks uint))
    (let (
        (sender tx-sender)
        (current-block stacks-block-height)
    )
        (asserts! (not (default-to false (map-get? switch-exists { owner: sender }))) ERR_ALREADY_EXISTS)
        (asserts! (>= timeout-blocks MIN_TIMEOUT_BLOCKS) ERR_INVALID_TIMEOUT)
        (asserts! (<= timeout-blocks MAX_TIMEOUT_BLOCKS) ERR_INVALID_TIMEOUT)
        (asserts! (not (is-eq sender beneficiary)) ERR_UNAUTHORIZED)
        
        (map-set switches
            { owner: sender }
            {
                beneficiary: beneficiary,
                balance: u0,
                last-checkin: current-block,
                timeout-blocks: timeout-blocks,
                created-at: current-block
            }
        )
        (map-set switch-exists { owner: sender } true)
        (var-set total-switches (+ (var-get total-switches) u1))
        (ok true)
    )
)

(define-public (deposit (amount uint))
    (let (
        (sender tx-sender)
        (switch-data (unwrap! (map-get? switches { owner: sender }) ERR_NOT_FOUND))
        (current-balance (get balance switch-data))
    )
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        
        (try! (stx-transfer? amount sender (as-contract tx-sender)))
        
        (map-set switches
            { owner: sender }
            (merge switch-data { balance: (+ current-balance amount) })
        )
        (var-set total-value-locked (+ (var-get total-value-locked) amount))
        (ok true)
    )
)

(define-public (checkin)
    (let (
        (sender tx-sender)
        (switch-data (unwrap! (map-get? switches { owner: sender }) ERR_NOT_FOUND))
    )
        (map-set switches
            { owner: sender }
            (merge switch-data { last-checkin: stacks-block-height })
        )
        (ok true)
    )
)

(define-public (withdraw (amount uint))
    (let (
        (sender tx-sender)
        (switch-data (unwrap! (map-get? switches { owner: sender }) ERR_NOT_FOUND))
        (current-balance (get balance switch-data))
    )
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        (asserts! (>= current-balance amount) ERR_INSUFFICIENT_BALANCE)
        
        (try! (as-contract (stx-transfer? amount tx-sender sender)))
        
        (map-set switches
            { owner: sender }
            (merge switch-data { balance: (- current-balance amount) })
        )
        (var-set total-value-locked (- (var-get total-value-locked) amount))
        (ok true)
    )
)

(define-public (claim-inheritance (owner principal))
    (let (
        (sender tx-sender)
        (switch-data (unwrap! (map-get? switches { owner: owner }) ERR_NOT_FOUND))
        (beneficiary (get beneficiary switch-data))
        (balance (get balance switch-data))
        (last-checkin (get last-checkin switch-data))
        (timeout-blocks (get timeout-blocks switch-data))
    )
        (asserts! (is-eq sender beneficiary) ERR_UNAUTHORIZED)
        (asserts! (>= stacks-block-height (+ last-checkin timeout-blocks)) ERR_STILL_ACTIVE)
        (asserts! (> balance u0) ERR_INSUFFICIENT_BALANCE)
        
        (try! (as-contract (stx-transfer? balance tx-sender beneficiary)))
        
        (map-delete switches { owner: owner })
        (map-delete switch-exists { owner: owner })
        (var-set total-switches (- (var-get total-switches) u1))
        (var-set total-value-locked (- (var-get total-value-locked) balance))
        (ok balance)
    )
)

(define-public (update-beneficiary (new-beneficiary principal))
    (let (
        (sender tx-sender)
        (switch-data (unwrap! (map-get? switches { owner: sender }) ERR_NOT_FOUND))
    )
        (asserts! (not (is-eq sender new-beneficiary)) ERR_UNAUTHORIZED)
        
        (map-set switches
            { owner: sender }
            (merge switch-data { beneficiary: new-beneficiary })
        )
        (ok true)
    )
)

(define-public (update-timeout (new-timeout-blocks uint))
    (let (
        (sender tx-sender)
        (switch-data (unwrap! (map-get? switches { owner: sender }) ERR_NOT_FOUND))
    )
        (asserts! (>= new-timeout-blocks MIN_TIMEOUT_BLOCKS) ERR_INVALID_TIMEOUT)
        (asserts! (<= new-timeout-blocks MAX_TIMEOUT_BLOCKS) ERR_INVALID_TIMEOUT)
        
        (map-set switches
            { owner: sender }
            (merge switch-data { 
                timeout-blocks: new-timeout-blocks,
                last-checkin: stacks-block-height
            })
        )
        (ok true)
    )
)

(define-public (emergency-withdraw)
    (let (
        (sender tx-sender)
        (switch-data (unwrap! (map-get? switches { owner: sender }) ERR_NOT_FOUND))
        (balance (get balance switch-data))
    )
        (asserts! (> balance u0) ERR_INSUFFICIENT_BALANCE)
        
        (try! (as-contract (stx-transfer? balance tx-sender sender)))
        
        (map-delete switches { owner: sender })
        (map-delete switch-exists { owner: sender })
        (var-set total-switches (- (var-get total-switches) u1))
        (var-set total-value-locked (- (var-get total-value-locked) balance))
        (ok balance)
    )
)

(define-read-only (get-switch (owner principal))
    (map-get? switches { owner: owner })
)

(define-read-only (get-switch-status (owner principal))
    (match (map-get? switches { owner: owner })
        switch-data 
        (let (
            (last-checkin (get last-checkin switch-data))
            (timeout-blocks (get timeout-blocks switch-data))
            (blocks-since-checkin (- stacks-block-height last-checkin))
        )
            (ok {
                active: (< blocks-since-checkin timeout-blocks),
                blocks-until-expiry: (if (< blocks-since-checkin timeout-blocks)
                    (some (- timeout-blocks blocks-since-checkin))
                    none
                ),
                blocks-since-checkin: blocks-since-checkin,
                can-claim: (>= blocks-since-checkin timeout-blocks)
            })
        )
        ERR_NOT_FOUND
    )
)

(define-read-only (check-inheritance-ready (owner principal))
    (match (map-get? switches { owner: owner })
        switch-data 
        (let (
            (last-checkin (get last-checkin switch-data))
            (timeout-blocks (get timeout-blocks switch-data))
        )
            (ok (>= stacks-block-height (+ last-checkin timeout-blocks)))
        )
        ERR_NOT_FOUND
    )
)

(define-read-only (get-contract-info)
    (ok {
        total-switches: (var-get total-switches),
        total-value-locked: (var-get total-value-locked),
        min-timeout-blocks: MIN_TIMEOUT_BLOCKS,
        max-timeout-blocks: MAX_TIMEOUT_BLOCKS
    })
)

(define-read-only (switch-exists-check (owner principal))
    (default-to false (map-get? switch-exists { owner: owner }))
)

(define-read-only (get-beneficiary (owner principal))
    (match (map-get? switches { owner: owner })
        switch-data (ok (get beneficiary switch-data))
        ERR_NOT_FOUND
    )
)

(define-read-only (get-balance (owner principal))
    (match (map-get? switches { owner: owner })
        switch-data (ok (get balance switch-data))
        ERR_NOT_FOUND
    )
)
