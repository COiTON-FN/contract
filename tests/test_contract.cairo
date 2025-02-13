use starknet::ContractAddress;
use core::option::OptionTrait;
use core::starknet::SyscallResultTrait;
use starknet::testing::set_block_timestamp;
use core::result::ResultTrait;
use core::traits::{TryInto, Into};
use core::byte_array::ByteArray;


use snforge_std::{
    declare, start_cheat_caller_address, stop_cheat_caller_address, ContractClassTrait,
    DeclareResultTrait, spy_events, EventSpyAssertionsTrait, get_class_hash
};


use coiton::mods::interfaces::ierc721::{IERC721Dispatcher, IERC721DispatcherTrait};
use coiton::mods::interfaces::ierc20::{IERC20Dispatcher, IERC20DispatcherTrait};
use coiton::mods::interfaces::icoiton::{ICoitonDispatcher, ICoitonDispatcherTrait};
use coiton::mods::{types, errors, events, tokens};
use coiton::mods::types::{User, UserType, Listing, ListingTag, PurchaseRequest};
use coiton::mods::events::{UserEventType, CreateListing, PurchaseRequestType};
use coiton::Coiton::{Event};


const ADMIN: felt252 = 'ADMIN';


fn _setup_() -> ContractAddress {
    let coiton = declare("Coiton").unwrap().contract_class();
    let mut events_constructor_calldata: Array<felt252> = array![ADMIN];
    let (coiton_contract_address, _) = coiton.deploy(@events_constructor_calldata).unwrap();
    return (coiton_contract_address);
}


fn _deploy_coiton_erc721(admin: ContractAddress) -> ContractAddress {
    let coiton_erc721_class_hash = declare("MyToken").unwrap().contract_class();

    let mut events_constructor_calldata: Array<felt252> = array![admin.try_into().unwrap()];
    let (coiton_erc721_contract_address, _) = coiton_erc721_class_hash
        .deploy(@events_constructor_calldata)
        .unwrap();

    return (coiton_erc721_contract_address);
}

fn __deploy_Coiton_erc20__(admin: ContractAddress) -> ContractAddress {
    let coiton_erc20_class_hash = declare("CTN").unwrap().contract_class();

    let mut events_constructor_calldata: Array<felt252> = array![admin.try_into().unwrap()];
    let (coiton_erc20_contract_address, _) = coiton_erc20_class_hash
        .deploy(@events_constructor_calldata)
        .unwrap();

    return (coiton_erc20_contract_address);
}

fn USER() -> ContractAddress {
    return 'recipient'.try_into().unwrap();
}


#[test]
fn test_register_user_as_entity() {
    let coiton_contract_address = _setup_();
    let coiton = ICoitonDispatcher { contract_address: coiton_contract_address };

    let User: ContractAddress = USER();
    start_cheat_caller_address(coiton_contract_address, User);

    let details: ByteArray = "TEST_USERS_ENTITY";
    coiton.register(UserType::Entity, details);

    let is_registered = coiton.get_user(User);
    assert!(is_registered.details == "TEST_USERS_ENTITY", "ALREADY_EXISTS");
    stop_cheat_caller_address(coiton_contract_address);
}

#[test]
fn test_register_user_as_individual() {
    let coiton_contract_address = _setup_();
    let coiton = ICoitonDispatcher { contract_address: coiton_contract_address };

    let User: ContractAddress = USER();
    start_cheat_caller_address(coiton_contract_address, User);

    let details: ByteArray = "TEST_USERS_INDIVIDUAL";
    coiton.register(UserType::Individual, details);

    let is_registered = coiton.get_user(User);
    assert!(is_registered.details == "TEST_USERS_INDIVIDUAL", "ALREADY_EXISTS");

    stop_cheat_caller_address(coiton_contract_address);
}

#[test]
#[should_panic(expected: 'ALREADY_EXIST')]
fn test_register_user_entity_twice() {
    let coiton_contract_address = _setup_();
    let coiton = ICoitonDispatcher { contract_address: coiton_contract_address };

    let User: ContractAddress = USER();
    start_cheat_caller_address(coiton_contract_address, User);

    // register as entity

    let details: ByteArray = "TEST_USERS_ENTITY";
    coiton.register(UserType::Entity, details);
    let is_registered_entity = coiton.get_user(User);
    assert!(is_registered_entity.details == "TEST_USERS_ENTITY", "ALREADY_EXISTS");

    let details1: ByteArray = "TEST_USERS_ENTITY";
    coiton.register(UserType::Entity, details1);
    let is_registered_entity1 = coiton.get_user(User);
    assert!(is_registered_entity1.details == "TEST_USERS_ENTITY", "ALREADY_EXISTS");

    stop_cheat_caller_address(coiton_contract_address);
}

#[test]
#[should_panic(expected: 'ALREADY_EXIST')]
fn test_register_user_individual_twice() {
    let coiton_contract_address = _setup_();
    let coiton = ICoitonDispatcher { contract_address: coiton_contract_address };

    let User: ContractAddress = USER();
    start_cheat_caller_address(coiton_contract_address, User);

    // register as entity

    let details: ByteArray = "TEST_USERS_INDIVIDUAL";
    coiton.register(UserType::Individual, details);
    let is_registered_entity = coiton.get_user(User);
    assert!(is_registered_entity.details == "TEST_USERS_INDIVIDUAL", "ALREADY_EXISTS");

    let details1: ByteArray = "TEST_USERS_INDIVIDUAL";
    coiton.register(UserType::Individual, details1);
    let is_registered_entity1 = coiton.get_user(User);
    assert!(is_registered_entity1.details == "TEST_USERS_INDIVIDUAL", "ALREADY_EXISTS");

    stop_cheat_caller_address(coiton_contract_address);
}


#[test]
fn test_register_user_emit_event() {
    let coiton_contract_address = _setup_();
    let coiton = ICoitonDispatcher { contract_address: coiton_contract_address };

    let User: ContractAddress = USER();
    let mut spy = spy_events();
    start_cheat_caller_address(coiton_contract_address, User);

    let details: ByteArray = "TEST_USERS_ENTITY";
    coiton.register(UserType::Entity, details);

    let is_registered = coiton.get_user(User);
    assert!(is_registered.details == "TEST_USERS_ENTITY", "ALREADY_EXISTS");

    // Check if the event was emitted
    let expected_event = Event::User(
        events::User { id: 1, address: User, event_type: UserEventType::Register, },
    );
    spy.assert_emitted(@array![(coiton_contract_address, expected_event)]);
    stop_cheat_caller_address(coiton_contract_address);
}


#[test]
fn test_verify_user() {
    let coiton_contract_address = _setup_();
    let coiton = ICoitonDispatcher { contract_address: coiton_contract_address };

    let User: ContractAddress = USER();
    let Owner = coiton.get_owner();

    start_cheat_caller_address(coiton_contract_address, User);
    let details: ByteArray = "TEST_USERS_ENTITY";
    coiton.register(UserType::Entity, details);
    let is_registered = coiton.get_user(User);
    assert!(is_registered.details == "TEST_USERS_ENTITY", "ALREADY_EXISTS");
    stop_cheat_caller_address(coiton_contract_address);

    start_cheat_caller_address(coiton_contract_address, Owner);
    coiton.verify_user(User);
    let is_verified = coiton.get_user(User);
    assert!(is_verified.verified == true, "NOT_VERIFIED");
    stop_cheat_caller_address(coiton_contract_address);
}


#[test]
fn test_verify_user_emit_event() {
    let coiton_contract_address = _setup_();
    let coiton = ICoitonDispatcher { contract_address: coiton_contract_address };

    let User: ContractAddress = USER();
    let Owner = coiton.get_owner();
    let mut spy = spy_events();

    start_cheat_caller_address(coiton_contract_address, User);
    let details: ByteArray = "TEST_USERS_ENTITY";
    coiton.register(UserType::Entity, details);
    let is_registered = coiton.get_user(User);
    assert!(is_registered.details == "TEST_USERS_ENTITY", "ALREADY_EXISTS");
    stop_cheat_caller_address(coiton_contract_address);

    start_cheat_caller_address(coiton_contract_address, Owner);
    coiton.verify_user(User);
    let is_verified = coiton.get_user(User);
    assert!(is_verified.verified == true, "NOT_VERIFIED");

    // Check if the event was emitted
    let expected_event = Event::User(
        events::User { id: 1, address: Owner, event_type: UserEventType::Verify, },
    );
    spy.assert_emitted(@array![(coiton_contract_address, expected_event)]);
    stop_cheat_caller_address(coiton_contract_address);
}


#[test]
#[should_panic(expected: 'UNAUTHORIZED')]
fn test_verify_user_unauthorized() {
    let coiton_contract_address = _setup_();
    let coiton = ICoitonDispatcher { contract_address: coiton_contract_address };

    let User: ContractAddress = USER();
    let Owner = coiton.get_owner();

    start_cheat_caller_address(coiton_contract_address, User);
    let details: ByteArray = "TEST_USERS_ENTITY";
    coiton.register(UserType::Entity, details);
    let is_registered = coiton.get_user(User);
    assert!(is_registered.details == "TEST_USERS_ENTITY", "ALREADY_EXISTS");
    stop_cheat_caller_address(coiton_contract_address);

    start_cheat_caller_address(coiton_contract_address, User);
    coiton.verify_user(User);
    let is_verified = coiton.get_user(User);
    assert!(is_verified.verified == true, "NOT_VERIFIED");
    stop_cheat_caller_address(coiton_contract_address);
}


#[test]
#[should_panic(expected: 'NOT_REGISTERED')]
fn test_verify_user_not_registered() {
    let coiton_contract_address = _setup_();
    let coiton = ICoitonDispatcher { contract_address: coiton_contract_address };

    let User: ContractAddress = USER();
    let Owner = coiton.get_owner();

    start_cheat_caller_address(coiton_contract_address, Owner);
    coiton.verify_user(User);
    stop_cheat_caller_address(coiton_contract_address);
}

