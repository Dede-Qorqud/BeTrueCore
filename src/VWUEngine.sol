// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
 * ═════════════════════════════════════════════════════════════════════════════
 * BeTrueCore — VWUEngine.sol
 * Vote Weight Unit / Verified Wisdom Unit — Computation Engine
 *
 * Author:  Farman Guliyev (Safarnur)
 * ORCID:   0009-0004-4841-594X
 * GitHub:  github.com/Dede-Qorqud/BeTrueCore
 * Version: 0.4 — privacy fixes: VWU_CAP protected, status anonymous
 * ═════════════════════════════════════════════════════════════════════════════
 *
 * VWU — двойное название, одна мера:
 *   Vote Weight Unit     — техническое: единица веса голоса
 *   Verified Wisdom Unit — смысловое:   единица верифицированной мудрости
 *
 * "Varlıq özü imzadır" — присутствие само есть подпись.
 * VWU измеряет не факт владения активом, а траекторию участия.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * ОТКРЫТАЯ ЧАСТЬ ФОРМУЛЫ (preprint [11], DOI: 10.5281/zenodo.22179301):
 *
 *   base_delta = 0.4 × A + 0.6 × Q
 *
 *   A — коэффициент активности ∈ [0,100]
 *       Отражает глубину прохождения семишагового цикла:
 *       A = steps_completed × 100 / 7
 *       0 шагов = 0, 7 шагов = 100
 *
 *   Q — коэффициент качества
 *       Q = 100 если финальный выбор совпал с взвешенным большинством
 *       Q = 50  если финальный выбор расходится с большинством
 *
 * Полная спецификация (нелинейный фактор, параметры EMA, momentum)
 * защищена в мастер-документе (OpenTimestamps SHA-256). NDA required.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * КЛЮЧЕВЫЕ СВОЙСТВА:
 *
 *   1. Необратимость базового балла   — VWU_BASE начисляется при регистрации,
 *                                        никакой механизм не может его уменьшить
 *   2. Ограниченность сверху          — VWU не превышает VWU_CAP (VERITAS_ZK)
 *                                        preprint [11]: «boundedness is not a
 *                                        technical constraint but a normative one»
 *   3. Нелинейность роста             — diminishing returns; быстрое накопление
 *                                        архитектурно невозможно
 *   4. Молчание — суверенное решение  — отсутствие участника НЕ уменьшает VWU;
 *                                        уменьшается только дельта следующей сессии
 *   5. Непроизводимость траектории    — поведенческий ряд нельзя подделать в масштабе
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * CONTINUITY PENALTY (preprint [11]):
 *
 *   ≤ 30 дней отсутствия  — полная дельта (коэффициент 1.0)
 *   30–180 дней           — линейное уменьшение от 1.0 до 0.5
 *   > 180 дней            — максимальный штраф: дельта × 0.5
 *
 *   VWU при этом НЕ уменьшается. Только дельта следующей сессии.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * СЕМИШАГОВЫЙ ЦИКЛ (preprint [12], DOI: 10.5281/zenodo.22537058):
 *
 *   Два участника с одинаковым ответом YES/NO могут иметь разный вес —
 *   в зависимости от того, сколько из семи шагов они прошли.
 *   steps_completed: 0 = нет участия, 7 = полный цикл.
 *   «The dilemma remains binary — yes or no — but the seven steps measure
 *    the seriousness of the path toward that binary choice.»
 * ═════════════════════════════════════════════════════════════════════════════
 */

/// @title VWUEngine
/// @notice Вычисляет и обновляет Vote Weight Unit / Verified Wisdom Unit
contract VWUEngine {

    // ══════════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ══════════════════════════════════════════════════════════════════════

    /// @notice Базовый балл при регистрации — «присутствие само есть подпись»
    /// @dev Необратим. Preprint [11]: «this score is irreversible and non-redeemable»
    uint256 public constant VWU_BASE = 1;

    // Пороги статусов
    uint256 public constant VWU_SOLO       = 0;
    uint256 public constant VWU_SELFLY     = 100;   // 1.00 VWU
    uint256 public constant VWU_UNIVERSAL  = 300;   // 3.00 VWU
    uint256 public constant VWU_HONORIS    = 700;   // 7.00 VWU
    uint256 public constant VWU_LUMINARE   = 1500;  // 15.00 VWU
    uint256 public constant VWU_VERITAS_ZK = 3000;  // 30.00 VWU

    /// @notice Верхняя граница VWU — архитектурный принцип ограниченности.
    /// @dev Существование границы публично. Конкретное значение защищено
    ///      в мастер-документе BeTrueCore (OpenTimestamps SHA-256, NDA required).
    ///      Preprint [11]: «boundedness is not a technical constraint but a normative one»
    uint256 private constant VWU_CAP = 3000; // [PROTECTED — не раскрывать в документации]

    /// @notice Шагов в семишаговом цикле
    uint256 public constant CYCLE_STEPS = 7;

    // ══════════════════════════════════════════════════════════════════════
    // ENUMS
    // ══════════════════════════════════════════════════════════════════════

    enum Status {
        SOLO,       // Copper   — вход в систему
        SELFLY,     // Bronze   — индивидуальный сигнал сформирован
        UNIVERSAL,  // Titanium — устойчивое участие
        HONORIS,    // Silver   — высокое качество суждения
        LUMINARE,   // Gold     — якорь сообщества
        VERITAS_ZK  // Platinum — ZK-верифицированный лидер
    }

    // ══════════════════════════════════════════════════════════════════════
    // STATE
    // ══════════════════════════════════════════════════════════════════════

    /// @notice VWU баланс участника
    /// @dev private — участник видит только свой баланс через getMyVWU().
    ///      Чужой баланс недоступен никому.
    ///      Preprint [11]: «VWU status is not a public attribute»
    mapping(address => uint256) private vwu;

    /// @notice Временная метка последней сессии (для continuity penalty)
    mapping(address => uint256) public lastSessionTimestamp;

    /// @notice Счётчик сессий участника
    mapping(address => uint256) public sessionCount;

    /// @notice Флаг регистрации (отличает VWU=1 от незарегистрированных)
    mapping(address => bool) public registered;

    /// @notice Количество участников на каждом уровне статуса
    /// @dev Публично — видны «звёзды», но не чьи они.
    ///      Обновляется при каждом StatusAdvanced.
    mapping(Status => uint256) public statusCount;

    address public owner;
    address public coordinator;

    // ══════════════════════════════════════════════════════════════════════
    // STRUCTS
    // ══════════════════════════════════════════════════════════════════════

    /// @notice Результат сессии, передаваемый координатором после time lock
    struct SessionResult {
        address participant;

        /// @notice Шагов пройдено в семишаговом цикле (0–7)
        /// @dev Preprint [12]: глубина цикла определяет вес,
        ///      даже если финальный ответ одинаков с другим участником
        uint8   steps_completed;

        /// @notice Совпал ли финальный выбор с взвешенным большинством
        bool    aligned_majority;

        uint256 session_timestamp;
    }

    // ══════════════════════════════════════════════════════════════════════
    // EVENTS
    // ══════════════════════════════════════════════════════════════════════

    event ParticipantInitialized(
        address indexed participant,
        uint256 base_vwu
    );

    event VWUUpdated(
        address indexed participant,
        uint256 new_vwu,
        uint256 delta,
        uint8   steps_completed,
        bool    aligned_majority
    );

    event ContinuityPenalty(
        address indexed participant,
        uint256 gap_days,
        uint256 penalty_factor
    );

    event StatusAdvanced(
        address indexed participant,
        Status  new_status,
        uint256 vwu_at_advance
    );

    // ══════════════════════════════════════════════════════════════════════
    // ERRORS
    // ══════════════════════════════════════════════════════════════════════

    error NotCoordinator();
    error NotOwner();
    error AlreadyRegistered(address participant);
    error NotRegistered(address participant);
    error InvalidStepsCompleted(uint8 steps);

    // ══════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ══════════════════════════════════════════════════════════════════════

    constructor(address _coordinator) {
        owner       = msg.sender;
        coordinator = _coordinator;
    }

    // ══════════════════════════════════════════════════════════════════════
    // MODIFIERS
    // ══════════════════════════════════════════════════════════════════════

    modifier onlyCoordinator() {
        if (msg.sender != coordinator) revert NotCoordinator();
        _;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    // ══════════════════════════════════════════════════════════════════════
    // REGISTRATION
    // ══════════════════════════════════════════════════════════════════════

    /// @notice Инициализировать участника при регистрации
    /// @dev Начисляет VWU_BASE = 1 — необратимый базовый балл.
    ///      Preprint [11]: «Every verified participant receives a non-zero
    ///      base score upon registration. This score is irreversible.»
    ///      Вызывается координатором после верификации ZK identity proof.
    function initializeParticipant(address participant)
        external
        onlyCoordinator
    {
        if (registered[participant]) revert AlreadyRegistered(participant);

        registered[participant] = true;
        vwu[participant]        = VWU_BASE;
        statusCount[Status.SOLO]++;

        emit ParticipantInitialized(participant, VWU_BASE);
    }

    // ══════════════════════════════════════════════════════════════════════
    // CORE — UPDATE VWU
    // ══════════════════════════════════════════════════════════════════════

    /// @notice Обновить VWU после сессии (вызывается координатором после time lock)
    /// @dev Молчание суверенно — VWU не уменьшается при отсутствии.
    ///      Только дельта следующей сессии корректируется continuity penalty.
    function updateVWU(SessionResult memory result) external onlyCoordinator {
        address p = result.participant;

        if (!registered[p])              revert NotRegistered(p);
        if (result.steps_completed > 7)  revert InvalidStepsCompleted(result.steps_completed);

        Status status_before = getStatus(p);

        // ── Шаг 1: Базовая дельта ─────────────────────────────────────────
        // A = steps_completed × 100 / 7  (семишаговый цикл → 0..100)
        uint256 A = uint256(result.steps_completed) * 100 / CYCLE_STEPS;
        uint256 Q = result.aligned_majority ? 100 : 50;

        // base_delta = 0.4 × A + 0.6 × Q  (открытая часть формулы)
        uint256 base_delta = (40 * A + 60 * Q) / 100;

        // ── Шаг 2: Нелинейный фактор роста ───────────────────────────────
        // Diminishing returns: каждая следующая единица требует
        // большего реального участия. Быстрое накопление невозможно.
        // Полная формула защищена. Ниже — публичная аппроксимация.
        uint256 current       = vwu[p];
        uint256 growth_factor = 10000 * 100 / (100 * 100 + current);
        uint256 delta         = base_delta * growth_factor / 10000;

        // ── Шаг 3: Continuity adjustment ─────────────────────────────────
        // VWU НЕ уменьшается. Только дельта следующей сессии.
        if (lastSessionTimestamp[p] > 0 &&
            result.session_timestamp > lastSessionTimestamp[p])
        {
            uint256 gap_days =
                (result.session_timestamp - lastSessionTimestamp[p]) / 1 days;

            if (gap_days > 30) {
                uint256 penalty_factor = gap_days > 180
                    ? 50
                    : 100 - ((gap_days - 30) * 50 / 150);

                delta = delta * penalty_factor / 100;
                emit ContinuityPenalty(p, gap_days, penalty_factor);
            }
        }

        // ── Шаг 4: Применить дельту с верхней границей ───────────────────
        // Preprint [11]: «no participant can accumulate unlimited weight»
        uint256 new_vwu = current + delta;
        if (new_vwu > VWU_CAP) new_vwu = VWU_CAP;

        vwu[p]                  = new_vwu;
        lastSessionTimestamp[p] = result.session_timestamp;
        sessionCount[p]++;

        emit VWUUpdated(p, new_vwu, delta,
                        result.steps_completed, result.aligned_majority);

        // ── Шаг 5: Обновить счётчик статусов и событие ───────────────────
        // statusCount публичен — видно сколько участников на каком уровне,
        // но не кто именно. «Звёзды видны, но не чьи они.»
        Status status_after = _computeStatus(new_vwu);
        if (status_after != status_before) {
            if (statusCount[status_before] > 0) {
                statusCount[status_before]--;
            }
            statusCount[status_after]++;
            emit StatusAdvanced(p, status_after, new_vwu);
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS — ЛИЧНЫЕ (только сам участник)
    // ══════════════════════════════════════════════════════════════════════

    /// @notice Участник видит свой собственный статус
    /// @dev msg.sender — только сам. Чужой статус недоступен.
    ///      Preprint [11]: «VWU status is not a public attribute»
    function getMyStatus() external view returns (Status) {
        return _computeStatus(vwu[msg.sender]);
    }

    /// @notice Участник видит свой собственный VWU баланс
    function getMyVWU() external view returns (uint256) {
        return vwu[msg.sender];
    }

    /// @notice VWU как целое и дробное (850 → integer=8, decimal=50)
    function getMyVWUFormatted()
        external view
        returns (uint256 integer, uint256 decimal)
    {
        uint256 v = vwu[msg.sender];
        integer = v / 100;
        decimal = v % 100;
    }

    /// @notice Сколько VWU до следующего статуса (только для себя)
    function myVWUToNextStatus()
        external view
        returns (uint256 needed, Status next)
    {
        uint256 v = vwu[msg.sender];
        if (v < VWU_SELFLY)     return (VWU_SELFLY    - v, Status.SELFLY);
        if (v < VWU_UNIVERSAL)  return (VWU_UNIVERSAL  - v, Status.UNIVERSAL);
        if (v < VWU_HONORIS)    return (VWU_HONORIS    - v, Status.HONORIS);
        if (v < VWU_LUMINARE)   return (VWU_LUMINARE   - v, Status.LUMINARE);
        if (v < VWU_VERITAS_ZK) return (VWU_VERITAS_ZK - v, Status.VERITAS_ZK);
        return (0, Status.VERITAS_ZK);
    }

    // ══════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS — ПУБЛИЧНЫЕ (агрегированные, без привязки к личности)
    // ══════════════════════════════════════════════════════════════════════

    /// @notice Распределение участников по уровням статуса
    /// @dev Публично — видно сколько «звёзд» каждого цвета.
    ///      Чьи они — не раскрывается.
    ///      Аналог: в ночном небе видно звёзды, но не чьи они.
    function getStatusDistribution()
        external view
        returns (
            uint256 solo,
            uint256 selfly,
            uint256 universal,
            uint256 honoris,
            uint256 luminare,
            uint256 veritas_zk
        )
    {
        solo       = statusCount[Status.SOLO];
        selfly     = statusCount[Status.SELFLY];
        universal  = statusCount[Status.UNIVERSAL];
        honoris    = statusCount[Status.HONORIS];
        luminare   = statusCount[Status.LUMINARE];
        veritas_zk = statusCount[Status.VERITAS_ZK];
    }

    /// @notice Предпросмотр дельты без записи (для off-chain симуляции)
    /// @dev Только для самого участника — использует msg.sender
    function previewMyDelta(
        uint8 steps_completed,
        bool  aligned_majority
    ) external view returns (uint256 delta) {
        if (steps_completed > 7) return 0;

        uint256 A             = uint256(steps_completed) * 100 / CYCLE_STEPS;
        uint256 Q             = aligned_majority ? 100 : 50;
        uint256 base_delta    = (40 * A + 60 * Q) / 100;
        uint256 current       = vwu[msg.sender];
        uint256 growth_factor = 10000 * 100 / (100 * 100 + current);
        delta                 = base_delta * growth_factor / 10000;
    }

    // ══════════════════════════════════════════════════════════════════════
    // INTERNAL
    // ══════════════════════════════════════════════════════════════════════

    /// @notice Вычислить статус по значению VWU (внутренняя функция)
    function _computeStatus(uint256 v) internal pure returns (Status) {
        if (v >= VWU_VERITAS_ZK) return Status.VERITAS_ZK;
        if (v >= VWU_LUMINARE)   return Status.LUMINARE;
        if (v >= VWU_HONORIS)    return Status.HONORIS;
        if (v >= VWU_UNIVERSAL)  return Status.UNIVERSAL;
        if (v >= VWU_SELFLY)     return Status.SELFLY;
        return Status.SOLO;
    }

    // ══════════════════════════════════════════════════════════════════════
    // ADMIN
    // ══════════════════════════════════════════════════════════════════════

    function setCoordinator(address _coordinator) external onlyOwner {
        coordinator = _coordinator;
    }
}
