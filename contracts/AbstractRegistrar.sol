pragma solidity ^0.4.0;

import './AbstractENS.sol';

contract Deed {

    function Deed(address _owner) payable;

    function setOwner(address newOwner);

    function setRegistrar(address newRegistrar);

    function setBalance(uint newValue, bool throwOnFailure);

    /**
     * @dev Close a deed and refund a specified fraction of the bid value
     *
     * @param refundRatio The amount*1/1000 to refund
     */
    function closeDeed(uint refundRatio);

    /**
     * @dev Close a deed and refund a specified fraction of the bid value
     */
    function destroyDeed();
}

contract AbstractRegistrar{
  AbstractENS public ens;
  bytes32 public rootNode;

  mapping (bytes32 => entry) _entries;
  mapping (address => mapping(bytes32 => Deed)) public sealedBids;

  enum Mode { Open, Auction, Owned, Forbidden, Reveal, NotYetAvailable }

  uint32 constant totalAuctionLength = 5 days;
  uint32 constant revealPeriod = 48 hours;
  uint32 public constant launchLength = 8 weeks;

  uint constant minPrice = 0.01 ether;
  uint public registryStarted;

  event AuctionStarted(bytes32 indexed hash, uint registrationDate);
  event NewBid(bytes32 indexed hash, address indexed bidder, uint deposit);
  event BidRevealed(bytes32 indexed hash, address indexed owner, uint value, uint8 status);
  event HashRegistered(bytes32 indexed hash, address indexed owner, uint value, uint registrationDate);
  event HashReleased(bytes32 indexed hash, uint value);
  event HashInvalidated(bytes32 indexed hash, string indexed name, uint value, uint registrationDate);

  struct entry {
    Deed deed;
    uint registrationDate;
    uint value;
    uint highestBid;
  }

  // State transitions for names:
  //   Open -> Auction (startAuction)
  //   Auction -> Reveal
  //   Reveal -> Owned
  //   Reveal -> Open (if nobody bid)
  //   Owned -> Open (releaseDeed or invalidateName)
  function state(bytes32 _hash) constant returns (Mode);

  function entries(bytes32 _hash) constant returns (Mode, address, uint, uint, uint) {
    entry h = _entries[_hash];
    return (state(_hash), h.deed, h.registrationDate, h.value, h.highestBid);
  }

  /**
  * @dev Constructs a new Registrar, with the provided address as the owner of the root node.
  *
  * @param _ens The address of the ENS
  * @param _rootNode The hash of the rootnode.
  */
  function Registrar(AbstractENS _ens, bytes32 _rootNode, uint _startDate);

  function isAllowed(bytes32 _hash, uint _timestamp) constant returns (bool allowed);

  /**
  * @dev Returns available date for hash
  *
  * The available time from the `registryStarted` for a hash is proportional
  * to its numeric value.
  *
  * @param _hash The hash to start an auction on
  */
  function getAllowedTime(bytes32 _hash) constant returns (uint timestamp);

  /**
  * @dev Start an auction for an available hash
  *
  * @param _hash The hash to start an auction on
  */
  function startAuction(bytes32 _hash);
  /**
  * @dev Start multiple auctions for better anonymity
  *
  * Anyone can start an auction by sending an array of hashes that they want to bid for.
  * Arrays are sent so that someone can open up an auction for X dummy hashes when they
  * are only really interested in bidding for one. This will increase the cost for an
  * attacker to simply bid blindly on all new auctions. Dummy auctions that are
  * open but not bid on are closed after a week.
  *
  * @param _hashes An array of hashes, at least one of which you presumably want to bid on
  */
  function startAuctions(bytes32[] _hashes);

  /**
  * @dev Hash the values required for a secret bid
  *
  * @param hash The node corresponding to the desired namehash
  * @param value The bid amount
  * @param salt A random value to ensure secrecy of the bid
  * @return The hash of the bid values
  */
  function shaBid(bytes32 hash, address owner, uint value, bytes32 salt) constant returns (bytes32 sealedBid);
  /**
  * @dev Submit a new sealed bid on a desired hash in a blind auction
  *
  * Bids are sent by sending a message to the main contract with a hash and an amount. The hash
  * contains information about the bid, including the bidded hash, the bid amount, and a random
  * salt. Bids are not tied to any one auction until they are revealed. The value of the bid
  * itself can be masqueraded by sending more than the value of your actual bid. This is
  * followed by a 48h reveal period. Bids revealed after this period will be burned and the ether unrecoverable.
  * Since this is an auction, it is expected that most public hashes, like known domains and common dictionary
  * words, will have multiple bidders pushing the price up.
  *
  * @param sealedBid A sealedBid, created by the shaBid function
  */
  function newBid(bytes32 sealedBid) payable;

  /**
  * @dev Start a set of auctions and bid on one of them
  *
  * This method functions identically to calling `startAuctions` followed by `newBid`,
  * but all in one transaction.
  *
  * @param hashes A list of hashes to start auctions on.
  * @param sealedBid A sealed bid for one of the auctions.
  */
  function startAuctionsAndBid(bytes32[] hashes, bytes32 sealedBid) payable;

  /**
  * @dev Submit the properties of a bid to reveal them
  *
  * @param _hash The node in the sealedBid
  * @param _value The bid amount in the sealedBid
  * @param _salt The sale in the sealedBid
  */
  function unsealBid(bytes32 _hash, uint _value, bytes32 _salt);
  /**
  * @dev Cancel a bid
  *
  * @param seal The value returned by the shaBid function
  */
  function cancelBid(address bidder, bytes32 seal);

  /**
  * @dev Finalize an auction after the registration date has passed
  *
  * @param _hash The hash of the name the auction is for
  */
  function finalizeAuction(bytes32 _hash);
  /**
  * @dev The owner of a domain may transfer it to someone else at any time.
  *
  * @param _hash The node to transfer
  * @param newOwner The address to transfer ownership to
  */
  function transfer(bytes32 _hash, address newOwner);
  /**
  * @dev After some time, or if we're no longer the registrar, the owner can release
  *      the name and get their ether back.
  *
  * @param _hash The node to release
  */
  function releaseDeed(bytes32 _hash);

  /**
  * @dev Submit a name 6 characters long or less. If it has been registered,
  *      the submitter will earn 50% of the deed value.
  *
  * We are purposefully handicapping the simplified registrar as a way
  * to force it into being restructured in a few years.
  *
  * @param unhashedName An invalid name to search for in the registry.
  */
  function invalidateName(string unhashedName);

  /**
  * @dev Allows anyone to delete the owner and resolver records for a (subdomain of) a
  *      name that is not currently owned in the registrar. If passing, eg, 'foo.bar.eth',
  *      the owner and resolver fields on 'foo.bar.eth' and 'bar.eth' will all be cleared.
  *
  * @param labels A series of label hashes identifying the name to zero out, rooted at the
  *        registrar's root. Must contain at least one element. For instance, to zero
  *        'foo.bar.eth' on a registrar that owns '.eth', pass an array containing
  *        [sha3('foo'), sha3('bar')].
  */
  function eraseNode(bytes32[] labels);

  /**
  * @dev Transfers the deed to the current registrar, if different from this one.
  *
  * Used during the upgrade process to a permanent registrar.
  *
  * @param _hash The name hash to transfer.
  */
  function transferRegistrars(bytes32 _hash);

  /**
  * @dev Accepts a transfer from a previous registrar; stubbed out here since there
  *      is no previous registrar implementing this interface.
  *
  * @param hash The sha3 hash of the label to transfer.
  * @param deed The Deed object for the name being transferred in.
  * @param registrationDate The date at which the name was originally registered.
  */
  function acceptRegistrarTransfer(bytes32 hash, Deed deed, uint registrationDate);
}
