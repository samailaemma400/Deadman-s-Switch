(define-constant contract-owner tx-sender)

(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INSUFFICIENT_BALANCE (err u103))
(define-constant ERR_STILL_ACTIVE (err u104))
(define-constant ERR_INVALID_TIMEOUT (err u105))
(define-constant ERR_INVALID_AMOUNT (err u106))
(define-constant ERR_INVALID_PERCENTAGES (err u107))
(define-constant ERR_TOO_MANY_BENEFICIARIES (err u108))
(define-constant ERR_GRACE_PERIOD_ACTIVE (err u109))
(define-constant ERR_INVALID_GRACE_PERIOD (err u110))

(define-constant MIN_TIMEOUT_BLOCKS u144)
(define-constant MAX_TIMEOUT_BLOCKS u52560)
(define-constant MAX_BENEFICIARIES u10)
(define-constant MAX_GRACE_PERIOD_BLOCKS u4320)
(define-constant DEFAULT_GRACE_PERIOD_BLOCKS u1008)

(define-map switches
    { owner: principal }
    {
        beneficiary: principal,
        balance: uint,
        last-checkin: uint,
        timeout-blocks: uint,
        created-at: uint,
        grace-period-blocks: uint
    }
)

(define-map switch-exists { owner: principal } bool)

(define-map multi-beneficiaries
    { owner: principal, beneficiary: principal }
    { percentage: uint }
)

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
                created-at: current-block,
                grace-period-blocks: DEFAULT_GRACE_PERIOD_BLOCKS
            }
        )
        (map-set switch-exists { owner: sender } true)
        (var-set total-switches (+ (var-get total-switches) u1))
        (ok true)
    )
)

(define-public (create-multi-switch (beneficiaries (list 10 { beneficiary: principal, percentage: uint })) (timeout-blocks uint))
    (let (
        (sender tx-sender)
        (current-block stacks-block-height)
        (total-percentage (fold validate-and-sum-percentages beneficiaries u0))
    )
        (asserts! (not (default-to false (map-get? switch-exists { owner: sender }))) ERR_ALREADY_EXISTS)
        (asserts! (>= timeout-blocks MIN_TIMEOUT_BLOCKS) ERR_INVALID_TIMEOUT)
        (asserts! (<= timeout-blocks MAX_TIMEOUT_BLOCKS) ERR_INVALID_TIMEOUT)
        (asserts! (is-eq total-percentage u100) ERR_INVALID_PERCENTAGES)
        (asserts! (> (len beneficiaries) u0) ERR_INVALID_PERCENTAGES)
        (asserts! (<= (len beneficiaries) MAX_BENEFICIARIES) ERR_TOO_MANY_BENEFICIARIES)
        
        (map-set switches
            { owner: sender }
            {
                beneficiary: (get beneficiary (unwrap! (element-at beneficiaries u0) ERR_INVALID_PERCENTAGES)),
                balance: u0,
                last-checkin: current-block,
                timeout-blocks: timeout-blocks,
                created-at: current-block,
                grace-period-blocks: DEFAULT_GRACE_PERIOD_BLOCKS
            }
        )
        (fold store-beneficiary beneficiaries sender)
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
        (grace-period-blocks (get grace-period-blocks switch-data))
        (expiry-block (+ last-checkin timeout-blocks))
        (grace-end-block (+ expiry-block grace-period-blocks))
    )
        (asserts! (is-eq sender beneficiary) ERR_UNAUTHORIZED)
        (asserts! (>= stacks-block-height expiry-block) ERR_STILL_ACTIVE)
        (asserts! (>= stacks-block-height grace-end-block) ERR_GRACE_PERIOD_ACTIVE)
        (asserts! (> balance u0) ERR_INSUFFICIENT_BALANCE)
        
        (try! (as-contract (stx-transfer? balance tx-sender beneficiary)))
        
        (map-delete switches { owner: owner })
        (map-delete switch-exists { owner: owner })
        (var-set total-switches (- (var-get total-switches) u1))
        (var-set total-value-locked (- (var-get total-value-locked) balance))
        (ok balance)
    )
)

(define-public (claim-multi-inheritance (owner principal))
    (let (
        (sender tx-sender)
        (switch-data (unwrap! (map-get? switches { owner: owner }) ERR_NOT_FOUND))
        (balance (get balance switch-data))
        (last-checkin (get last-checkin switch-data))
        (timeout-blocks (get timeout-blocks switch-data))
        (grace-period-blocks (get grace-period-blocks switch-data))
        (expiry-block (+ last-checkin timeout-blocks))
        (grace-end-block (+ expiry-block grace-period-blocks))
        (beneficiary-data (unwrap! (map-get? multi-beneficiaries { owner: owner, beneficiary: sender }) ERR_UNAUTHORIZED))
        (percentage (get percentage beneficiary-data))
        (inheritance-amount (/ (* balance percentage) u100))
    )
        (asserts! (>= stacks-block-height expiry-block) ERR_STILL_ACTIVE)
        (asserts! (>= stacks-block-height grace-end-block) ERR_GRACE_PERIOD_ACTIVE)
        (asserts! (> balance u0) ERR_INSUFFICIENT_BALANCE)
        (asserts! (> inheritance-amount u0) ERR_INSUFFICIENT_BALANCE)
        
        (try! (as-contract (stx-transfer? inheritance-amount tx-sender sender)))
        
        (map-set switches
            { owner: owner }
            (merge switch-data { balance: (- balance inheritance-amount) })
        )
        (map-delete multi-beneficiaries { owner: owner, beneficiary: sender })
        (var-set total-value-locked (- (var-get total-value-locked) inheritance-amount))
        
        (let ((remaining-balance (- balance inheritance-amount)))
            (if (is-eq remaining-balance u0)
                (begin
                    (map-delete switches { owner: owner })
                    (map-delete switch-exists { owner: owner })
                    (var-set total-switches (- (var-get total-switches) u1))
                    (ok inheritance-amount)
                )
                (ok inheritance-amount)
            )
        )
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

(define-public (update-grace-period (new-grace-period-blocks uint))
    (let (
        (sender tx-sender)
        (switch-data (unwrap! (map-get? switches { owner: sender }) ERR_NOT_FOUND))
    )
        (asserts! (<= new-grace-period-blocks MAX_GRACE_PERIOD_BLOCKS) ERR_INVALID_GRACE_PERIOD)
        
        (map-set switches
            { owner: sender }
            (merge switch-data { grace-period-blocks: new-grace-period-blocks })
        )
        (ok true)
    )
)

(define-public (grace-period-rescue-checkin)
    (let (
        (sender tx-sender)
        (switch-data (unwrap! (map-get? switches { owner: sender }) ERR_NOT_FOUND))
        (last-checkin (get last-checkin switch-data))
        (timeout-blocks (get timeout-blocks switch-data))
        (grace-period-blocks (get grace-period-blocks switch-data))
        (expiry-block (+ last-checkin timeout-blocks))
        (grace-end-block (+ expiry-block grace-period-blocks))
    )
        (asserts! (>= stacks-block-height expiry-block) ERR_STILL_ACTIVE)
        (asserts! (< stacks-block-height grace-end-block) ERR_GRACE_PERIOD_ACTIVE)
        
        (map-set switches
            { owner: sender }
            (merge switch-data { last-checkin: stacks-block-height })
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
            (grace-period-blocks (get grace-period-blocks switch-data))
            (blocks-since-checkin (- stacks-block-height last-checkin))
            (expiry-block (+ last-checkin timeout-blocks))
            (grace-end-block (+ expiry-block grace-period-blocks))
            (in-grace-period (and (>= stacks-block-height expiry-block) (< stacks-block-height grace-end-block)))
        )
            (ok {
                active: (< blocks-since-checkin timeout-blocks),
                blocks-until-expiry: (if (< blocks-since-checkin timeout-blocks)
                    (some (- timeout-blocks blocks-since-checkin))
                    none
                ),
                blocks-since-checkin: blocks-since-checkin,
                can-claim: (>= stacks-block-height grace-end-block),
                in-grace-period: in-grace-period,
                blocks-until-grace-end: (if in-grace-period
                    (some (- grace-end-block stacks-block-height))
                    none
                ),
                grace-period-blocks: grace-period-blocks
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
            (grace-period-blocks (get grace-period-blocks switch-data))
            (expiry-block (+ last-checkin timeout-blocks))
            (grace-end-block (+ expiry-block grace-period-blocks))
        )
            (ok (>= stacks-block-height grace-end-block))
        )
        ERR_NOT_FOUND
    )
)

(define-read-only (get-contract-info)
    (ok {
        total-switches: (var-get total-switches),
        total-value-locked: (var-get total-value-locked),
        min-timeout-blocks: MIN_TIMEOUT_BLOCKS,
        max-timeout-blocks: MAX_TIMEOUT_BLOCKS,
        default-grace-period-blocks: DEFAULT_GRACE_PERIOD_BLOCKS,
        max-grace-period-blocks: MAX_GRACE_PERIOD_BLOCKS
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

(define-private (validate-and-sum-percentages (beneficiary-entry { beneficiary: principal, percentage: uint }) (current-sum uint))
    (let (
        (percentage (get percentage beneficiary-entry))
        (beneficiary (get beneficiary beneficiary-entry))
    )
        (begin
            (asserts! (> percentage u0) u999)
            (asserts! (<= percentage u100) u999)
            (+ current-sum percentage)
        )
    )
)

(define-private (store-beneficiary (beneficiary-entry { beneficiary: principal, percentage: uint }) (owner principal))
    (let (
        (beneficiary (get beneficiary beneficiary-entry))
        (percentage (get percentage beneficiary-entry))
    )
        (begin
            (asserts! (not (is-eq owner beneficiary)) owner)
            (map-set multi-beneficiaries
                { owner: owner, beneficiary: beneficiary }
                { percentage: percentage }
            )
            owner
        )
    )
)

(define-read-only (get-beneficiary-percentage (owner principal) (beneficiary principal))
    (match (map-get? multi-beneficiaries { owner: owner, beneficiary: beneficiary })
        beneficiary-data (ok (get percentage beneficiary-data))
        ERR_NOT_FOUND
    )
)

(define-read-only (has-multi-beneficiaries (owner principal) (test-beneficiary principal))
    (is-some (map-get? multi-beneficiaries { owner: owner, beneficiary: test-beneficiary }))
)
