use starknet::ContractAddress;
#[starknet::interface]
pub trait IERC721<TContractState> {
    // fn safe_mint(
    //     ref self: TContractState, recipient: ContractAddress, token_id: u256, data:
    //     Span<felt252>,
    // );
    // fn owner(self: @TContractState) -> ContractAddress;
    fn mint_coiton_nft(ref self: TContractState, address: ContractAddress);
    fn get_last_minted_id(self: @TContractState) -> u256;
    fn get_user_token_id(self: @TContractState, user: ContractAddress) -> u256;
    fn get_token_mint_timestamp(self: @TContractState, token_id: u256) -> u64;
    fn get_approved(self: @TContractState, token_id: u256) -> ContractAddress;
    fn approve(ref self: TContractState, to: ContractAddress, token_id: u256);
    // fn transfer(
    //     ref self: TContractState, from: ContractAddress, to: ContractAddress, token_id: u256
    // );
    fn transfer_from(
        ref self: TContractState, from: ContractAddress, to: ContractAddress, token_id: u256
    );

    fn owner_of(self: @TContractState, token_id: u256) -> ContractAddress;
}
