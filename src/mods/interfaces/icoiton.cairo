use starknet::{ContractAddress, ClassHash};
use crate::mods::types::{User, UserType, ListingType, Listing, ListingTag, PurchaseRequest};


#[starknet::interface]
pub trait ICoiton<TContractState> {
    //  USER SECTION
    fn register(ref self: TContractState, user_type: UserType, details: ByteArray);
    fn verify_user(ref self: TContractState, address: ContractAddress);
    fn get_user(self: @TContractState, address: ContractAddress) -> User;
    //  LISTING SECTION
    fn create_listing(
        ref self: TContractState, listing_type: ListingType, price: u256, details: ByteArray
    );
    fn get_all_listings(self: @TContractState) -> Array<Listing>;
    fn get_listings_by_ids(self: @TContractState, ids: Array<u256>) -> Array<Listing>;
    fn get_listing(self: @TContractState, id: u256) -> Listing;
    fn get_user_listings(self: @TContractState, address: ContractAddress) -> Array<Listing>;
    fn create_purchase_request(ref self: TContractState, listing_id: u256, bid_price: Option<u256>);
    fn approve_purchase_request(ref self: TContractState, listing_id: u256, request_id: u256);
    fn get_listings_with_purchase_requests(
        self: @TContractState, address: ContractAddress
    ) -> Array<Listing>;
    fn update_listing_tag(ref self: TContractState, listing_id: u256, tag: ListingTag);
    fn get_listing_purchase_requests(self: @TContractState, id: u256) -> Array<PurchaseRequest>;
    fn get_owner(self: @TContractState) -> ContractAddress;
    fn get_purchase(self: @TContractState, listing_id: u256, request_id: u256) -> PurchaseRequest;
    fn get_wallet_balance(self: @TContractState) -> u256;


    //  TOKENS SECTION
    fn set_erc721(ref self: TContractState, address: ContractAddress);
    fn set_erc20(ref self: TContractState, address: ContractAddress);
    fn get_erc20(self: @TContractState) -> ContractAddress;
    fn get_erc721(self: @TContractState) -> ContractAddress;

    // UTILITY FUNCTIONS
    fn upgrade(ref self: TContractState, impl_hash: ClassHash);
    fn version(self: @TContractState) -> u16;
    fn withdraw(ref self: TContractState);
}
