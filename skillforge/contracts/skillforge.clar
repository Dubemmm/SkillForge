;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-SKILL (err u101))
(define-constant ERR-ALREADY-VERIFIED (err u102))
(define-constant ERR-NOT-MENTOR (err u103))
(define-constant ERR-INVALID-PATH (err u104))

;; Data variables
(define-non-fungible-token skill-token uint)

(define-map skills
    uint 
    {
        name: (string-ascii 50),
        description: (string-ascii 256),
        level: uint,
        verified: bool,
        owner: principal,
        mentor: (optional principal),
        path-id: uint,
        timestamp: uint
    }
)

(define-map skill-paths 
    uint 
    {
        name: (string-ascii 50),
        description: (string-ascii 256),
        required-skills: (list 20 uint),
        creator: principal
    }
)

(define-map mentors
    principal 
    {
        active: bool,
        skills-verified: uint,
        reputation: uint
    }
)

(define-data-var skill-nonce uint u0)
(define-data-var path-nonce uint u0)

;; Authorization
(define-public (register-mentor)
    (let
        ((caller tx-sender))
        (asserts! (is-none (get-mentor caller)) (err u105))
        (ok (map-set mentors 
            caller
            {
                active: true,
                skills-verified: u0,
                reputation: u0
            }
        ))
    )
)

;; Skill Management
(define-public (create-skill (name (string-ascii 50)) 
                           (description (string-ascii 256)) 
                           (path-id uint))
    (let
        ((skill-id (+ (var-get skill-nonce) u1))
         (caller tx-sender))
        
        ;; Verify path exists
        (asserts! (is-some (map-get? skill-paths path-id)) (err u104))
        
        ;; Mint NFT
        (try! (nft-mint? skill-token skill-id caller))
        
        ;; Create skill record
        (map-set skills 
            skill-id
            {
                name: name,
                description: description,
                level: u1,
                verified: false,
                owner: caller,
                mentor: none,
                path-id: path-id,
                timestamp: block-height
            }
        )
        
        ;; Increment nonce
        (var-set skill-nonce skill-id)
        (ok skill-id)
    )
)

(define-public (verify-skill (skill-id uint))
    (let
        ((caller tx-sender)
         (skill (unwrap! (map-get? skills skill-id) ERR-INVALID-SKILL))
         (mentor-data (unwrap! (get-mentor caller) ERR-NOT-MENTOR)))
        
        ;; Verify caller is active mentor
        (asserts! (get active mentor-data) ERR-NOT-MENTOR)
        ;; Verify skill not already verified
        (asserts! (not (get verified skill)) ERR-ALREADY-VERIFIED)
        
        ;; Update skill verification
        (map-set skills 
            skill-id
            (merge skill {
                verified: true,
                mentor: (some caller)
            })
        )
        
        ;; Update mentor stats
        (map-set mentors
            caller
            (merge mentor-data {
                skills-verified: (+ (get skills-verified mentor-data) u1)
            })
        )
        
        (ok true)
    )
)

;; Skill Path Management
(define-public (create-skill-path (name (string-ascii 50)) 
                                (description (string-ascii 256))
                                (required-skills (list 20 uint)))
    (let
        ((path-id (+ (var-get path-nonce) u1))
         (caller tx-sender))
        
        (map-set skill-paths
            path-id
            {
                name: name,
                description: description,
                required-skills: required-skills,
                creator: caller
            }
        )
        
        (var-set path-nonce path-id)
        (ok path-id)
    )
)

;; Read-only functions
(define-read-only (get-skill (skill-id uint))
    (map-get? skills skill-id)
)

(define-read-only (get-skill-path (path-id uint))
    (map-get? skill-paths path-id)
)

(define-read-only (get-mentor (address principal))
    (map-get? mentors address)
)

(define-read-only (get-token-uri (token-id uint))
    (ok none)
)

;; NFT trait implementation
(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
        (nft-transfer? skill-token token-id sender recipient)
    )
)