
use starknet::ContractAddress;
#[starknet::interface]
pub trait IERC721<TContractState> {
    fn safe_mint(
        ref self: TContractState, recipient: ContractAddress, token_id: u256, data: Span<felt252>,
    );
}
