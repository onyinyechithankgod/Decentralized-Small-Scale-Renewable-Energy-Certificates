;; Aggregation Contract
;; Combines small producers for market access

(define-map aggregation-pools
  { pool-id: uint }
  {
    name: (string-utf8 100),
    admin: principal,
    total-energy: uint,
    active: bool
  }
)

(define-map pool-members
  { pool-id: uint, member: principal }
  { joined-at: uint }
)

(define-map member-contributions
  { pool-id: uint, member: principal }
  { energy-amount: uint }
)

(define-map pool-certificates
  { pool-id: uint, certificate-id: uint }
  {
    owner: principal,
    energy-amount: uint,
    contributed-at: uint
  }
)

(define-data-var last-pool-id uint u0)

(define-public (create-pool (name (string-utf8 100)))
  (let ((new-id (+ (var-get last-pool-id) u1)))
    (begin
      (var-set last-pool-id new-id)
      (map-set aggregation-pools
        { pool-id: new-id }
        {
          name: name,
          admin: tx-sender,
          total-energy: u0,
          active: true
        }
      )
      (ok new-id)
    )
  )
)

(define-public (join-pool (pool-id uint))
  (begin
    (asserts! (is-some (map-get? aggregation-pools { pool-id: pool-id })) (err u404))
    (map-set pool-members
      { pool-id: pool-id, member: tx-sender }
      { joined-at: block-height }
    )
    (map-set member-contributions
      { pool-id: pool-id, member: tx-sender }
      { energy-amount: u0 }
    )
    (ok true)
  )
)

(define-public (contribute-to-pool
    (pool-id uint)
    (certificate-id uint)
    (energy-amount uint))
  (let (
    (pool (map-get? aggregation-pools { pool-id: pool-id }))
  )
    (begin
      (asserts! (is-some pool) (err u404))
      (asserts! (get active (unwrap-panic pool)) (err u403))

      ;; Record certificate contribution
      (map-set pool-certificates
        { pool-id: pool-id, certificate-id: certificate-id }
        {
          owner: tx-sender,
          energy-amount: energy-amount,
          contributed-at: block-height
        }
      )

      ;; Update member contribution
      (match (map-get? member-contributions { pool-id: pool-id, member: tx-sender })
        current-contribution (map-set member-contributions
                              { pool-id: pool-id, member: tx-sender }
                              { energy-amount: (+ (get energy-amount current-contribution) energy-amount) })
        (map-set member-contributions
          { pool-id: pool-id, member: tx-sender }
          { energy-amount: energy-amount })
      )

      ;; Update pool total
      (map-set aggregation-pools
        { pool-id: pool-id }
        (merge (unwrap-panic pool)
              { total-energy: (+ (get total-energy (unwrap-panic pool)) energy-amount) })
      )

      (ok true)
    )
  )
)

(define-read-only (get-pool (pool-id uint))
  (map-get? aggregation-pools { pool-id: pool-id })
)

(define-read-only (get-member-contribution (pool-id uint) (member principal))
  (map-get? member-contributions { pool-id: pool-id, member: member })
)

(define-read-only (is-pool-member (pool-id uint) (member principal))
  (is-some (map-get? pool-members { pool-id: pool-id, member: member }))
)

(define-read-only (get-certificate-contribution (pool-id uint) (certificate-id uint))
  (map-get? pool-certificates { pool-id: pool-id, certificate-id: certificate-id })
)

