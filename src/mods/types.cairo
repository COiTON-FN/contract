use starknet::ContractAddress;


#[derive(Drop, Debug, PartialEq, Serde, starknet::Store,)]
pub enum UserType {
    #[default]
    Individual,
    Entity,
}

#[derive(Drop, Debug , PartialEq,  Serde, starknet::Store)]
pub struct User {
    pub id: u256,
    pub verified: bool,
    pub details: ByteArray,
    pub user_type: UserType,
    pub address: ContractAddress,
    pub registered: bool
}

#[derive(Drop, Debug, PartialEq, Serde, starknet::Store)]
pub enum ListingTag {
    Sold,
    ForSale
}

#[derive(Drop, Debug, PartialEq, Serde, starknet::Store)]
pub struct Listing {
    pub id: u256,
    pub details: ByteArray,
    pub owner: ContractAddress,
    pub price: u256,
    pub tag: ListingTag
}


#[derive(Drop, Debug, PartialEq,  Serde, starknet::Store)]
pub struct PurchaseRequest {
    pub listing_id: u256,
    pub request_id: u256,
    pub price: u256,
    pub initiator: ContractAddress,
    pub user: Option<User>
}
