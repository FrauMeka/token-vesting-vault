
 // SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract VestingVault is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct Schedule {
        address beneficiary;
        uint256 total;
        uint256 released;
        uint64 start;
        uint64 cliff;
        uint64 duration;
        uint64 revokedAt;
        bool revocable;
        bool revoked;
    }

    IERC20 public immutable token;
    uint256 public scheduleCount;
    uint256 public totalAllocated;

    mapping(uint256 => Schedule) public schedules;
    mapping(address => uint256[]) private _schedulesOf;

    event ScheduleCreated(
        uint256 indexed id,
        address indexed beneficiary,
        uint256 amount,
        uint64 start,
        uint64 cliff,
        uint64 duration,
        bool revocable
    );

    event Released(
        uint256 indexed id,
        address indexed beneficiary,
        uint256 amount
    );

    event Revoked(uint256 indexed id, uint256 returnedToOwner);

    event ScheduleTransferred(
        uint256 indexed id,
        address indexed from,
        address indexed to
    );

    constructor(IERC20 token_) Ownable(msg.sender) {
        require(address(token_) != address(0), "zero token");
        token = token_;
    }

    // STEP 1: Create a vesting schedule
    /// @notice Creates a new vesting schedule.
    /// @param beneficiary Address receiving the tokens.
    /// @param amount Total tokens promised.
    /// @param start Vesting start timestamp.
    /// @param cliff Lock period in seconds.
    /// @param duration Total vesting duration in seconds.
    /// @param revocable Whether the schedule can be revoked.
    function createSchedule(
        address beneficiary,
        uint256 amount,
        uint64 start,
        uint64 cliff,
        uint64 duration,
        bool revocable
    ) external onlyOwner returns (uint256 id) {
        require(beneficiary != address(0), "zero beneficiary");
        require(amount > 0, "zero amount");
        require(duration > 0, "zero duration");
        require(cliff <= duration, "invalid cliff");

        uint256 balance = token.balanceOf(address(this));

        require(
            balance >= totalAllocated &&
            balance - totalAllocated >= amount,
            "not enough tokens"
        );

        id = ++scheduleCount;

        schedules[id] = Schedule({
            beneficiary: beneficiary,
            total: amount,
            released: 0,
            start: start,
            cliff: cliff,
            duration: duration,
            revokedAt: 0,
            revocable: revocable,
            revoked: false
        });

        _schedulesOf[beneficiary].push(id);
        totalAllocated += amount;

        emit ScheduleCreated(
            id,
            beneficiary,
            amount,
            start,
            cliff,
            duration,
            revocable
        );
    }

    // STEP 2: Calculate vested tokens
    function _vested(
        Schedule storage s
    ) internal view returns (uint256) {
        uint256 t = s.revoked
            ? uint256(s.revokedAt)
            : block.timestamp;

        uint256 startTime = uint256(s.start);

        if (t < startTime + uint256(s.cliff)) {
            return 0;
        }

        if (t >= startTime + uint256(s.duration)) {
            return s.total;
        }

        return s.total * (t - startTime) / uint256(s.duration);
    }

    /// @notice Returns the total vested amount.
    /// @param id Schedule ID.
    function vestedAmount(
        uint256 id
    ) public view returns (uint256) {
        require(id > 0 && id <= scheduleCount, "unknown schedule");
        return _vested(schedules[id]);
    }

    /// @notice Returns tokens available for withdrawal.
    /// @param id Schedule ID.
    function releasable(
        uint256 id
    ) public view returns (uint256) {
        require(id > 0 && id <= scheduleCount, "unknown schedule");

        return _vested(schedules[id]) - schedules[id].released;
    }

    // STEP 3: Release available tokens
    /// @notice Transfers unlocked tokens to the beneficiary.
    /// @param id Schedule ID.
    function release(uint256 id) external nonReentrant {
        uint256 amount = releasable(id);

        require(amount > 0, "nothing to release");

        Schedule storage s = schedules[id];

        s.released += amount;
        totalAllocated -= amount;

        token.safeTransfer(s.beneficiary, amount);

        emit Released(id, s.beneficiary, amount);
    }

    // STEP 4: Revoke a schedule
    /// @notice Cancels future vesting and returns unvested tokens.
    /// @param id Schedule ID.
    function revoke(uint256 id) external onlyOwner nonReentrant {
        require(id > 0 && id <= scheduleCount, "unknown schedule");

        Schedule storage s = schedules[id];

        require(s.revocable, "not revocable");
        require(!s.revoked, "already revoked");

        uint256 vested = _vested(s);
        uint256 unvested = s.total - vested;

        s.revoked = true;
        s.revokedAt = uint64(block.timestamp);

        totalAllocated -= unvested;

        if (unvested > 0) {
            token.safeTransfer(owner(), unvested);
        }

        emit Revoked(id, unvested);
    }

    // STEP 5: Withdraw unallocated tokens
    /// @notice Withdraws tokens not reserved for beneficiaries.
    /// @param to Recipient address.
    /// @return amount Tokens withdrawn.
    function withdrawUnallocated(
        address to
    ) external onlyOwner nonReentrant returns (uint256 amount) {
        require(to != address(0), "zero address");

        uint256 balance = token.balanceOf(address(this));

        require(balance > totalAllocated, "nothing to withdraw");

        amount = balance - totalAllocated;

        token.safeTransfer(to, amount);
    }

    /// @notice Returns schedule IDs belonging to a beneficiary.
    /// @param beneficiary Address to look up.
    function schedulesOf(
        address beneficiary
    ) external view returns (uint256[] memory) {
        return _schedulesOf[beneficiary];
    }

    // BONUS: Transfer schedule
    /// @notice Transfers a schedule to another beneficiary.
    /// @param id Schedule ID.
    /// @param newBeneficiary New beneficiary address.
    function transferSchedule(
        uint256 id,
        address newBeneficiary
    ) external {
        require(id > 0 && id <= scheduleCount, "unknown schedule");

        Schedule storage s = schedules[id];

        address oldBeneficiary = s.beneficiary;

        require(msg.sender == oldBeneficiary, "not beneficiary");
        require(newBeneficiary != address(0), "zero address");
        require(newBeneficiary != oldBeneficiary, "same beneficiary");

        uint256[] storage oldIds = _schedulesOf[oldBeneficiary];

        for (uint256 i = 0; i < oldIds.length; i++) {
            if (oldIds[i] == id) {
                oldIds[i] = oldIds[oldIds.length - 1];
                oldIds.pop();
                break;
            }
        }

        s.beneficiary = newBeneficiary;

        _schedulesOf[newBeneficiary].push(id);

        emit ScheduleTransferred(
            id,
            oldBeneficiary,
            newBeneficiary
        );
    }
}

