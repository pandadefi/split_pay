# @version 0.3.7

from vyper.interfaces import ERC20

MAX_PAYEE: constant(uint256) = 100

# @dev Returns the address of the current owner.
owner: public(address)

# @dev Returns the address of the pending owner.
pending_owner: public(address)

# @dev payee
payees: public(DynArray[address, MAX_PAYEE])
# @dev payee allocation
allocs: public(HashMap[address, uint256])
total_alloc: public(uint256)


# @dev Emitted when the ownership transfer from
# `previous_owner` to `new_owner` is initiated.
event OwnershipTransferStarted:
    previous_owner: indexed(address)
    new_owner: indexed(address)


# @dev Emitted when the ownership is transferred
# from `previous_owner` to `new_owner`.
event OwnershipTransferred:
    previous_owner: indexed(address)
    new_owner: indexed(address)

# @dev Add payee
event PayeeAdded:
    payee: indexed(address)
    alloc: uint256

# @dev Remove payee
event PayeeRemoved:
    payee: indexed(address)

# @dev native token recieved 
event Payment:
    amount: uint256
    sender: indexed(address)


@external
@payable
def __init__():
    """
    @dev To omit the opcodes for checking the `msg.value`
         in the creation-time EVM bytecode, the constructor
         is declared as `payable`.
    @notice The `owner` role will be assigned to
            the `msg.sender`.
    """
    self._transfer_ownership(msg.sender)


@external
def add_payee(payee: address, alloc: uint256):
    self._check_owner()
    assert alloc != 0, "zero alloc"
    assert payee != empty(address), "invalid address"
    assert self.allocs[payee] == 0, "already exists"
    self.payees.append(payee)
    self.allocs[payee] = alloc
    self.total_alloc += alloc
    log PayeeAdded(payee, alloc)

@external
def remove_payee(payee: address):
    self._check_owner()
    old_aloc: uint256 = self.allocs[payee]
    assert old_aloc != 0, "zero alloc"
    for i in range(MAX_PAYEE):
        if self.payees[i] == payee:
            self.payees[i] = self.payees[len(self.payees) - 1]
            self.payees.pop()
            break
    self.allocs[payee] = 0
    self.total_alloc -= old_aloc
    log PayeeRemoved(payee)

@external
def distribute(tokens: ERC20[10]):
    total_alloc: uint256 = self.total_alloc
    for token in tokens:
        bal: uint256 = token.balanceOf(self)
        for payee in self.payees:
            token.transfer(payee, bal * self.allocs[payee] / total_alloc)

@external
def distribute_native():
    bal: uint256 = self.balance
    total_alloc: uint256 = self.total_alloc
    for payee in self.payees:
        send(payee, bal * self.allocs[payee] / total_alloc)


@external
def transfer_ownership(new_owner: address):
    """
    @dev Starts the ownership transfer of the contract
         to a new account `new_owner`.
    @notice Note that this function can only be
            called by the current `owner`. Also, there is
            no security risk in setting `new_owner` to the
            zero address as the default value of `pending_owner`
            is in fact already the zero address and the zero
            address cannot call `accept_ownership`. Eventually,
            the function replaces the pending transfer if
            there is one.
    @param new_owner The 20-byte address of the new owner.
    """
    self._check_owner()
    self.pending_owner = new_owner
    log OwnershipTransferStarted(self.owner, new_owner)


@external
def accept_ownership():
    """
    @dev The new owner accepts the ownership transfer.
    @notice Note that this function can only be
            called by the current `pending_owner`.
    """
    assert self.pending_owner == msg.sender, "Ownable2Step: caller is not the new owner"
    self._transfer_ownership(msg.sender)


@external
def renounce_ownership():
    """
    @dev Sourced from {Ownable-renounce_ownership}.
    @notice See {Ownable-renounce_ownership} for
            the function docstring.
    """
    self._check_owner()
    self._transfer_ownership(empty(address))


@internal
def _check_owner():
    """
    @dev Throws if the sender is not the owner.
    """
    assert msg.sender == self.owner, "Ownable2Step: caller is not the owner"


@internal
def _transfer_ownership(new_owner: address):
    """
    @dev Transfers the ownership of the contract
         to a new account `new_owner` and deletes
         any pending owner.
    @notice This is an `internal` function without
            access restriction.
    @param new_owner The 20-byte address of the new owner.
    """
    self.pending_owner = empty(address)
    old_owner: address = self.owner
    self.owner = new_owner
    log OwnershipTransferred(old_owner, new_owner)


@payable
@external
def execute(_target: address, _calldata: Bytes[100000], value: uint256):
    self._check_owner()
    raw_call(_target, _calldata, value=value)


@external
@payable
def __default__():
    log Payment(msg.value, msg.sender)
