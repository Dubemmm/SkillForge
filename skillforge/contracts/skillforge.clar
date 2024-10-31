;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-SKILL (err u101))
(define-constant ERR-ALREADY-VERIFIED (err u102))
(define-constant ERR-NOT-MENTOR (err u103))
(define-constant ERR-INVALID-PATH (err u104))
(define-constant ERR-INVALID-INPUT (err u105))
(define-constant ERR-MENTOR-ALREADY-REGISTERED (err u106))
(define-constant ERR-INVALID-RECIPIENT (err u107))
(define-constant ERR-NOT-OWNER (err u108))
(define-constant ERR-INVALID-LEVEL (err u109))
(define-constant ERR-COOLDOWN-ACTIVE (err u110))
(define-constant ERR-INSUFFICIENT-ENDORSEMENTS (err u111))
(define-constant ERR-INSUFFICIENT-STAKE (err u112))
(define-constant ERR-BADGE-NOT-FOUND (err u113))
(define-constant ERR-BADGE-EXPIRED (err u114))
(define-constant ERR-INVALID-PROPOSAL (err u115))
(define-constant ERR-VOTING-CLOSED (err u116))
(define-constant ERR-ALREADY-VOTED (err u117))
(define-constant ERR-INVALID-EXPIRATION (err u118))
(define-constant ERR-INVALID-REQUIREMENTS (err u119))
(define-constant ERR-INVALID-RARITY (err u120))
(define-constant ERR-INVALID-POINTS (err u121))
(define-constant ERR-INVALID-ACHIEVEMENT (err u122))
(define-constant ERR-INVALID-VOTE (err u123))

;; Data variables
(define-non-fungible-token skill-token uint)
(define-non-fungible-token badge-token uint)

(define-map skills
    uint 
    {
        name: (string-ascii 50),
        description: (string-ascii 256),
        level: uint,
        experience: uint,
        verified: bool,
        owner: principal,
        mentor: (optional principal),
        path-id: uint,
        timestamp: uint,
        last-level-up: uint,
        endorsements: (list 20 principal),
        achievements: (list 20 uint)
    }
)

(define-map skill-paths 
    uint 
    {
        name: (string-ascii 50),
        description: (string-ascii 256),
        required-skills: (list 20 uint),
        creator: principal,
        achievements: (list 20 uint)
    }
)

(define-map mentors
    principal 
    {
        active: bool,
        skills-verified: uint,
        reputation: uint,
        stake: uint,
        specializations: (list 10 uint),
        success-rate: uint,
        students: (list 100 principal),
        earnings: uint
    }
)

(define-map badges
    uint
    {
        name: (string-ascii 50),
        description: (string-ascii 256),
        issuer: principal,
        expiration: (optional uint),
        requirements: (list 5 uint),
        holders: (list 1000 principal)
    }
)

(define-map achievements
    uint
    {
        name: (string-ascii 50),
        description: (string-ascii 256),
        criteria: (string-ascii 256),
        rarity: uint,
        points: uint,
        holders: (list 1000 principal)
    }
)

(define-map governance-proposals
    uint
    {
        title: (string-ascii 50),
        description: (string-ascii 256),
        proposer: principal,
        start-block: uint,
        end-block: uint,
        min-votes: uint,
        yes-votes: uint,
        no-votes: uint,
        status: (string-ascii 20)
    }
)

(define-map votes
    { proposal-id: uint, voter: principal }
    bool
)

(define-data-var skill-nonce uint u0)
(define-data-var path-nonce uint u0)
(define-data-var badge-nonce uint u0)
(define-data-var achievement-nonce uint u0)
(define-data-var proposal-nonce uint u0)

;; Constants
(define-constant LEVEL-UP-COOLDOWN u43200) ;; ~30 days in blocks
(define-constant MIN-ENDORSEMENTS u5)
(define-constant MENTOR-STAKE u1000000) ;; 1 STX
(define-constant VOTING-PERIOD u1008) ;; ~7 days in blocks
(define-constant MAX-UINT u340282366920938463463374607431768211455)

;; Helper functions
(define-private (validate-string (input (string-ascii 256)) (max-length uint))
    (< (len input) max-length)
)

(define-private (validate-required-skills (skill-list (list 20 uint)))
    (<= (len skill-list) u20)
)

(define-private (is-valid-principal (address principal))
    (is-some (some address))
)

(define-private (can-level-up (skill-id uint))
    (match (map-get? skills skill-id)
        skill (let ((current-time (unwrap-panic (get-block-info? time u0))))
            (and
                (>= (- current-time (get last-level-up skill)) LEVEL-UP-COOLDOWN)
                (>= (len (get endorsements skill)) MIN-ENDORSEMENTS)
            ))
        false
    )
)

(define-private (validate-uint (value uint))
    (< value MAX-UINT)
)

;; Read-only functions
(define-read-only (get-mentor (address principal))
    (map-get? mentors address)
)

(define-read-only (get-skill (skill-id uint))
    (map-get? skills skill-id)
)

(define-read-only (get-skill-path (path-id uint))
    (map-get? skill-paths path-id)
)

(define-read-only (get-badge (badge-id uint))
    (map-get? badges badge-id)
)

(define-read-only (get-achievement (achievement-id uint))
    (map-get? achievements achievement-id)
)

(define-read-only (get-proposal (proposal-id uint))
    (map-get? governance-proposals proposal-id)
)

(define-read-only (get-vote (proposal-id uint) (voter principal))
    (map-get? votes { proposal-id: proposal-id, voter: voter })
)

(define-read-only (get-token-uri (token-id uint))
    (ok none)
)

;; Authorization
(define-public (register-mentor)
    (let
        ((caller tx-sender))
        (asserts! (is-none (get-mentor caller)) ERR-MENTOR-ALREADY-REGISTERED)
        (asserts! (>= (stx-get-balance caller) MENTOR-STAKE) ERR-INSUFFICIENT-STAKE)
        (try! (stx-transfer? MENTOR-STAKE caller (as-contract tx-sender)))
        (ok (map-set mentors 
            caller
            {
                active: true,
                skills-verified: u0,
                reputation: u100,
                stake: MENTOR-STAKE,
                specializations: (list ),
                success-rate: u0,
                students: (list ),
                earnings: u0
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
         (caller tx-sender)
         (current-time (unwrap-panic (get-block-info? time u0))))
        
        (asserts! (validate-string name u50) ERR-INVALID-INPUT)
        (asserts! (validate-string description u256) ERR-INVALID-INPUT)
        (asserts! (is-some (map-get? skill-paths path-id)) ERR-INVALID-PATH)
        
        (try! (nft-mint? skill-token skill-id caller))
        
        (map-set skills 
            skill-id
            {
                name: name,
                description: description,
                level: u1,
                experience: u0,
                verified: false,
                owner: caller,
                mentor: none,
                path-id: path-id,
                timestamp: current-time,
                last-level-up: current-time,
                endorsements: (list ),
                achievements: (list )
            }
        )
        
        (var-set skill-nonce skill-id)
        (ok skill-id)
    )
)

(define-public (verify-skill (skill-id uint))
    (let
        ((caller tx-sender)
         (skill (unwrap! (map-get? skills skill-id) ERR-INVALID-SKILL))
         (mentor-data (unwrap! (get-mentor caller) ERR-NOT-MENTOR)))
        
        (asserts! (get active mentor-data) ERR-NOT-MENTOR)
        (asserts! (not (get verified skill)) ERR-ALREADY-VERIFIED)
        
        (map-set skills 
            skill-id
            (merge skill {
                verified: true,
                mentor: (some caller)
            })
        )
        
        (map-set mentors
            caller
            (merge mentor-data {
                skills-verified: (+ (get skills-verified mentor-data) u1),
                reputation: (+ (get reputation mentor-data) u10),
                students: (unwrap-panic (as-max-len? (append (get students mentor-data) (get owner skill)) u100))
            })
        )
        
        (ok true)
    )
)

(define-public (level-up-skill (skill-id uint))
    (let
        ((caller tx-sender)
         (skill (unwrap! (map-get? skills skill-id) ERR-INVALID-SKILL))
         (current-time (unwrap-panic (get-block-info? time u0))))
        
        (asserts! (is-eq caller (get owner skill)) ERR-NOT-OWNER)
        (asserts! (get verified skill) ERR-INVALID-SKILL)
        (asserts! (< (get level skill) u10) ERR-INVALID-LEVEL)
        (asserts! (can-level-up skill-id) ERR-COOLDOWN-ACTIVE)
        
        (map-set skills 
            skill-id
            (merge skill {
                level: (+ (get level skill) u1),
                last-level-up: current-time,
                endorsements: (list )
            })
        )
        
        (ok true)
    )
)

(define-public (endorse-skill (skill-id uint))
    (let
        ((caller tx-sender)
         (skill (unwrap! (map-get? skills skill-id) ERR-INVALID-SKILL)))
        
        (asserts! (not (is-eq caller (get owner skill))) ERR-NOT-AUTHORIZED)
        (asserts! (is-some (get-mentor caller)) ERR-NOT-MENTOR)
        
        (map-set skills 
            skill-id
            (merge skill {
                endorsements: (unwrap-panic (as-max-len? (append (get endorsements skill) caller) u20))
            })
        )
        
        (ok true)
    )
)

(define-public (add-experience (skill-id uint) (exp-points uint))
    (let
        ((caller tx-sender)
         (skill (unwrap! (map-get? skills skill-id) ERR-INVALID-SKILL)))
        
        (asserts! (or (is-eq caller (get owner skill)) (is-eq (some caller) (get mentor skill))) ERR-NOT-AUTHORIZED)
        
        (map-set skills 
            skill-id
            (merge skill {
                experience: (+ (get experience skill) exp-points)
            })
        )
        
        (ok true)
    )
)

;; Badge Management
(define-public (create-badge (name (string-ascii 50)) 
                             (description (string-ascii 256))
                             (expiration (optional uint))
                             (requirements (list 5 uint)))
    (let
        ((badge-id (+ (var-get badge-nonce) u1))
         (caller tx-sender))
        
        (asserts! (validate-string name u50) ERR-INVALID-INPUT)
        (asserts! (validate-string description u256) ERR-INVALID-INPUT)
        (asserts! (match expiration exp (validate-uint exp) true) ERR-INVALID-EXPIRATION)
        (asserts! (fold and (map validate-uint requirements) true) ERR-INVALID-REQUIREMENTS)
        
        (map-set badges
            badge-id
            {
                name: name,
                description: description,
                issuer: caller,
                expiration: expiration,
                requirements: requirements,
                holders: (list )
            }
        )
        
        (var-set badge-nonce badge-id)
        (ok badge-id)
    )
)

;; Achievement Management
(define-public (create-achievement (name (string-ascii 50))
                                   (description (string-ascii 256))
                                   (criteria (string-ascii 256))
                                   (rarity uint)
                                   (points uint))
    (let
        ((achievement-id (+ (var-get achievement-nonce) u1))
         (caller tx-sender))
        
        (asserts! (validate-string name u50) ERR-INVALID-INPUT)
        (asserts! (validate-string description u256) ERR-INVALID-INPUT)
        (asserts! (validate-string criteria u256) ERR-INVALID-INPUT)
        (asserts! (validate-uint rarity) ERR-INVALID-RARITY)
        (asserts! (validate-uint points) ERR-INVALID-POINTS)
        
        (map-set achievements
            achievement-id
            {
                name: name,
                description: description,
                criteria: criteria,
                rarity: rarity,
                points: points,
                holders: (list )
            }
        )
        
        (var-set achievement-nonce achievement-id)
        (ok achievement-id)
    )
)

(define-public (vote-on-proposal (proposal-id uint) (vote bool))
    (let
        ((caller tx-sender)
         (proposal (unwrap! (map-get? governance-proposals proposal-id) ERR-INVALID-PROPOSAL))
         (current-time (unwrap-panic (get-block-info? time u0))))
        
        (asserts! (<= current-time (get end-block proposal)) ERR-VOTING-CLOSED)
        (asserts! (is-none (get-vote proposal-id caller)) ERR-ALREADY-VOTED)
        
        (map-set votes
            { proposal-id:  proposal-id, voter: caller }
            vote
        )
        
        (map-set governance-proposals
            proposal-id
            (merge proposal {
                yes-votes: (if vote (+ (get yes-votes proposal) u1) (get yes-votes proposal)),
                no-votes: (if (not vote) (+ (get no-votes proposal) u1) (get no-votes proposal))
            })
        )
        
        (ok true)
    )
)

;; Governance
(define-public (submit-proposal (title (string-ascii 50))
                                (description (string-ascii 256))
                                (min-votes uint))
    (let
        ((proposal-id (+ (var-get proposal-nonce) u1))
         (caller tx-sender)
         (current-time (unwrap-panic (get-block-info? time u0))))
        
        (asserts! (validate-string title u50) ERR-INVALID-INPUT)
        (asserts! (validate-string description u256) ERR-INVALID-INPUT)
        (asserts! (validate-uint min-votes) ERR-INVALID-INPUT)
        
        (map-set governance-proposals
            proposal-id
            {
                title: title,
                description: description,
                proposer: caller,
                start-block: current-time,
                end-block: (+ current-time VOTING-PERIOD),
                min-votes: min-votes,
                yes-votes: u0,
                no-votes: u0,
                status: "active"
            }
        )
        
        (var-set proposal-nonce proposal-id)
        (ok proposal-id)
    )
)

(define-public (finalize-proposal (proposal-id uint))
    (let
        ((proposal (unwrap! (map-get? governance-proposals proposal-id) ERR-INVALID-PROPOSAL))
         (current-time (unwrap-panic (get-block-info? time u0))))
        
        (asserts! (> current-time (get end-block proposal)) ERR-VOTING-CLOSED)
        (asserts! (is-eq (get status proposal) "active") ERR-INVALID-PROPOSAL)
        
        (let
            ((total-votes (+ (get yes-votes proposal) (get no-votes proposal)))
             (result (if (and (>= total-votes (get min-votes proposal))
                              (> (get yes-votes proposal) (get no-votes proposal)))
                         "passed"
                         "rejected")))
            
            (map-set governance-proposals
                proposal-id
                (merge proposal { status: result })
            )
            
            (ok result)
        )
    )
)

;; NFT trait implementation
(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
        (asserts! (is-some (nft-get-owner? skill-token token-id)) ERR-INVALID-SKILL)
        (asserts! (is-valid-principal recipient) ERR-INVALID-RECIPIENT)
        (nft-transfer? skill-token token-id sender recipient)
    )
)

;; Advanced Queries
(define-read-only (get-full-skill-details (skill-id uint))
    (let
        ((skill (unwrap! (map-get? skills skill-id) none))
         (path (unwrap! (map-get? skill-paths (get path-id skill)) none))
         (mentor-details (match (get mentor skill)
                            mentor (get-mentor mentor)
                            none)))
        (some {
            skill: skill,
            path: path,
            mentor: mentor-details
        })
    )
)

(define-read-only (get-mentor-performance (mentor principal))
    (match (get-mentor mentor)
        mentor-data (some {
            skills-verified: (get skills-verified mentor-data),
            success-rate: (get success-rate mentor-data),
            students: (get students mentor-data),
            earnings: (get earnings mentor-data)
        })
        none
    )
)

(define-read-only (get-achievement-statistics (achievement-id uint))
    (match (map-get? achievements achievement-id)
        achievement (some {
            name: (get name achievement),
            rarity: (get rarity achievement),
            points: (get points achievement),
            total-holders: (len (get holders achievement))
        })
        none
    )
)