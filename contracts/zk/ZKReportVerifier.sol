

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ZKReportVerifier
 * @notice Stores zk-verified parent report hashes for jobs.
 * @dev V1 is intentionally minimal and does NOT yet enforce proof verification.
 *      It is structured so a Groth16 verifier can be plugged in later.
 */
contract ZKReportVerifier {
    /// @notice jobId => verified parent report hash
    mapping(uint256 => bytes32) public verifiedReportHashByJob;

    /// @notice jobId => whether zk verification has been recorded
    mapping(uint256 => bool) public isJobZkVerified;

    /// @notice emitted when a job is marked as zk-verified
    event ReportVerified(uint256 indexed jobId, bytes32 reportHash, address indexed verifier);

    error AlreadyVerified(uint256 jobId);
    error InvalidInput();

    /**
     * @notice Submit a zk-verified report hash for a job
     * @dev In V1, proof is NOT validated yet. This function is a placeholder hook.
     *      Later, this will call a Groth16 verifier contract.
     */
    function submitZKReport(
        uint256 jobId,
        bytes32 reportHash,
        bytes calldata proof
    ) external {
        if (jobId == 0 || reportHash == bytes32(0)) {
            revert InvalidInput();
        }

        if (isJobZkVerified[jobId]) {
            revert AlreadyVerified(jobId);
        }

        // --- ZK verification hook (future) ---
        // bool ok = verifier.verifyProof(proof, publicSignals);
        // require(ok, "Invalid proof");
        // ------------------------------------

        verifiedReportHashByJob[jobId] = reportHash;
        isJobZkVerified[jobId] = true;

        emit ReportVerified(jobId, reportHash, msg.sender);
    }

    /**
     * @notice Read verified report hash
     */
    function getVerifiedReportHash(uint256 jobId) external view returns (bytes32) {
        return verifiedReportHashByJob[jobId];
    }

    /**
     * @notice Check if a job has been zk verified
     */
    function isVerified(uint256 jobId) external view returns (bool) {
        return isJobZkVerified[jobId];
    }
}