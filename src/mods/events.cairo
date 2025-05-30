use starknet::{ClassHash, ContractAddress};
#[derive(Copy, Drop, starknet::Event)]
pub struct Upgrade {
    #[key]
    pub implementation: ClassHash
}

#[derive(Copy, Drop, Serde)]
pub enum UserEventType {
    Register,
    Verify
}

#[derive(Copy, Drop, starknet::Event)]
pub struct User {
    #[key]
    pub id: u256,
    #[key]
    pub address: ContractAddress,
    pub event_type: UserEventType
}

#[derive(Copy, Drop, starknet::Event)]
pub struct CreateListing {
    #[key]
    pub id: u256,
    #[key]
    pub owner: ContractAddress,
    #[key]
    pub price: u256
}


#[derive(Copy, Drop, Serde)]
pub enum PurchaseRequestType {
    Create,
    Approve,
}

#[derive(Copy, Drop, starknet::Event)]
pub struct PurchaseRequest {
    #[key]
    pub listing_id: u256,
    #[key]
    pub request_id: u256,
    pub bid_price: Option<u256>,
    #[key]
    pub initiator: ContractAddress,
    pub request_type: PurchaseRequestType
}

