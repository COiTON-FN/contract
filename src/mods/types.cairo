use core::starknet::ContractAddress;
use starknet::class_hash::ClassHash;


#[derive(Drop, Serde, starknet::Store)]
pub enum UserType {
    Entity,
    Individual
}

#[derive(Drop, Serde, starknet::Store)]
pub struct User {
    pub id: u256,
    pub verified: bool,
    pub details: ByteArray,
    pub user_type: UserType,
    pub address: ContractAddress,
    pub registered: bool
}
