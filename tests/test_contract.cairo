use starknet::ContractAddress;
use core::option::OptionTrait;
use core::starknet::SyscallResultTrait;
use starknet::testing::set_block_timestamp;
use core::result::ResultTrait;
use core::traits::{TryInto, Into};
use core::byte_array::{ByteArray, ByteArrayTrait};


use snforge_std::{
    declare, start_cheat_caller_address, stop_cheat_caller_address, ContractClassTrait,
    DeclareResultTrait, spy_events, EventSpyAssertionsTrait, get_class_hash
};

use starknet::{ClassHash, get_block_timestamp};


use coiton::mods::interfaces::ierc721::{IERC721Dispatcher, IERC721DispatcherTrait};
use coiton::mods::interfaces::ierc20::{IERC20Dispatcher, IERC20DispatcherTrait};
use coiton::mods::interfaces::icoiton::{ICoitonDispatcher, ICoitonDispatcherTrait};
use coiton::mods::{types, errors, events, tokens};
use coiton::mods::types::{User, UserType, Listing, ListingTag, PurchaseRequest};
use coiton::mods::events::{UserEventType, CreateListing, PurchaseRequestType};
use coiton::Coiton::{Event};


const ADMIN: felt252 = 'ADMIN';

fn OWNER() -> ContractAddress {
    'owner'.try_into().unwrap()
}


fn _setup_() -> ContractAddress {
    let coiton = declare("Coiton").unwrap().contract_class();

    let mut calldata = array![];
    OWNER().serialize(ref calldata);
    // coiton_erc.serialize(ref calldata);
    // coiton_erc721.serialize(ref calldata);
    let (coiton_contract_address, _) = coiton.deploy(@calldata).unwrap();
    let coiton_erc20 = __deploy_Coiton_erc20__(coiton_contract_address);
    let coiton_erc721 = _deploy_coiton_erc721(coiton_contract_address);
    let coiton = ICoitonDispatcher { contract_address: coiton_contract_address };
    start_cheat_caller_address(coiton_contract_address, OWNER());

    coiton.set_erc20(coiton_erc20);
    coiton.set_erc721(coiton_erc721);
    stop_cheat_caller_address(coiton_contract_address);

    return coiton_contract_address;
}


fn _deploy_coiton_erc721(admin: ContractAddress) -> ContractAddress {
    let coiton_erc721_class_hash = declare("MyToken").unwrap().contract_class();

    // let mut events_constructor_calldata: Array<felt252> = array![ADMIN];
    let mut calldata = array![];
    admin.serialize(ref calldata);
    let (coiton_erc721_contract_address, _) = coiton_erc721_class_hash.deploy(@calldata).unwrap();
    // println!("{:?}", coiton_erc721_contract_address);
    return coiton_erc721_contract_address;
}

fn __deploy_Coiton_erc20__(admin: ContractAddress) -> ContractAddress {
    let coiton_erc20_class_hash = declare("CoitonToken").unwrap().contract_class();
    let mut calldata = array![];
    admin.serialize(ref calldata);
    // let mut events_constructor_calldata: Array<felt252> = array![ADMIN];
    let (coiton_erc20_contract_address, _) = coiton_erc20_class_hash.deploy(@calldata).unwrap();

    return coiton_erc20_contract_address;
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

#[test]
fn test_create_listing() {
    let coiton_contract_address = _setup_();
    let coiton = ICoitonDispatcher { contract_address: coiton_contract_address };

    let User: ContractAddress = USER();

    start_cheat_caller_address(coiton_contract_address, User);
    let details: ByteArray = "TEST_USERS_ENTITY";
    coiton.register(UserType::Entity, details);
    let is_registered = coiton.get_user(User);
    assert!(is_registered.details == "TEST_USERS_ENTITY", "ALREADY_EXISTS");
    stop_cheat_caller_address(coiton_contract_address);

    start_cheat_caller_address(coiton_contract_address, User);
    let listing_details: ByteArray = "TEST_LISTING";
    coiton.create_listing(100, listing_details);
    let listings = coiton.get_listing(1);
    assert!(listings.details == "TEST_LISTING", "NOT_CREATED");

    stop_cheat_caller_address(coiton_contract_address);
}


#[test]
fn test_create_listing_by_id() {
    let coiton_contract_address = _setup_();
    let coiton = ICoitonDispatcher { contract_address: coiton_contract_address };

    let User: ContractAddress = USER();

    start_cheat_caller_address(coiton_contract_address, User);
    let details: ByteArray = "TEST_USERS_ENTITY";
    coiton.register(UserType::Entity, details);
    let is_registered = coiton.get_user(User);
    assert!(is_registered.details == "TEST_USERS_ENTITY", "ALREADY_EXISTS");
    stop_cheat_caller_address(coiton_contract_address);

    start_cheat_caller_address(coiton_contract_address, User);
    let listing_details: ByteArray = "TEST_LISTING";
    coiton.create_listing(100, listing_details);
    let listings = coiton.get_listings_by_ids(array![1_u256]);
    assert!(listings[0].id == @1_u256, "NOT_CREATED");
    stop_cheat_caller_address(coiton_contract_address);
}


#[test]
fn test_create_listing_by_user() {
    let coiton_contract_address = _setup_();
    let coiton = ICoitonDispatcher { contract_address: coiton_contract_address };

    let User: ContractAddress = USER();

    start_cheat_caller_address(coiton_contract_address, User);
    let details: ByteArray = "TEST_USERS_ENTITY";
    coiton.register(UserType::Entity, details);
    let is_registered = coiton.get_user(User);
    assert!(is_registered.details == "TEST_USERS_ENTITY", "ALREADY_EXISTS");
    stop_cheat_caller_address(coiton_contract_address);

    start_cheat_caller_address(coiton_contract_address, User);
    let listing_details: ByteArray = "TEST_LISTING";
    coiton.create_listing(100, listing_details);
    let listings = coiton.get_user_listings(User);
    assert_eq!(
        listings,
        array![
            Listing {
                id: 1, details: "TEST_LISTING", owner: User, price: 100, tag: ListingTag::ForSale
            }
        ]
    );
    stop_cheat_caller_address(coiton_contract_address);
}

#[test]
fn test_all_create_listing() {
    let coiton_contract_address = _setup_();
    let coiton = ICoitonDispatcher { contract_address: coiton_contract_address };

    let User: ContractAddress = USER();

    start_cheat_caller_address(coiton_contract_address, User);
    let details: ByteArray = "TEST_USERS_ENTITY";
    coiton.register(UserType::Entity, details);
    let is_registered = coiton.get_user(User);
    assert!(is_registered.details == "TEST_USERS_ENTITY", "ALREADY_EXISTS");
    stop_cheat_caller_address(coiton_contract_address);

    start_cheat_caller_address(coiton_contract_address, User);
    let listing_details: ByteArray = "TEST_LISTING";
    coiton.create_listing(100, listing_details);
    let listings = coiton.get_all_listings();
    assert_eq!(
        listings,
        array![
            Listing {
                id: 1, details: "TEST_LISTING", owner: User, price: 100, tag: ListingTag::ForSale
            }
        ]
    );
    stop_cheat_caller_address(coiton_contract_address);
}


#[test]
#[should_panic(expected: 'NOT_REGISTERED')]
fn test_create_listing_without_registering() {
    let coiton_contract_address = _setup_();
    let coiton = ICoitonDispatcher { contract_address: coiton_contract_address };

    let User: ContractAddress = USER();

    start_cheat_caller_address(coiton_contract_address, User);
    let listing_details: ByteArray = "TEST_LISTING";

    // Create listings
    coiton.create_listing(100, listing_details);

    // Get listings by id's
    let listings = coiton.get_listing(1);
    assert!(listings.details == "TEST_LISTING", "NOT_CREATED");

    //  Get listings by array indexs

    let listings_by_id = coiton.get_listings_by_ids(array![1_u256]);
    assert!(listings_by_id[0].id == @1_u256, "NOT_CREATED");

    // Get listings by user
    let listings_by_users = coiton.get_user_listings(User);
    assert_eq!(
        listings_by_users,
        array![
            Listing {
                id: 1, details: "TEST_LISTING", owner: User, price: 100, tag: ListingTag::ForSale
            }
        ]
    );

    // Get all listings
    let listings_by_all = coiton.get_all_listings();
    assert_eq!(
        listings_by_all,
        array![
            Listing {
                id: 1, details: "TEST_LISTING", owner: User, price: 100, tag: ListingTag::ForSale
            }
        ]
    );

    stop_cheat_caller_address(coiton_contract_address);
}

#[test]
fn test_nft_was_minted_after_listings_was_created() {
    let coiton_contract_address = _setup_();
    let coiton = ICoitonDispatcher { contract_address: coiton_contract_address };
    let erc721 = IERC721Dispatcher { contract_address: coiton.get_erc721() };

    let User: ContractAddress = USER();

    // Register user
    start_cheat_caller_address(coiton_contract_address, User);
    let details: ByteArray = "TEST_USERS_ENTITY";
    coiton.register(UserType::Entity, details);
    let is_registered = coiton.get_user(User);
    assert!(is_registered.details == "TEST_USERS_ENTITY", "ALREADY_EXISTS");
    stop_cheat_caller_address(coiton_contract_address);

    //User create listing
    start_cheat_caller_address(coiton_contract_address, User);

    let listing_dettails: ByteArray = "TEST_LISTING";

    coiton.create_listing(100, listing_dettails);

    // Get listings by user
    let listings_by_users = coiton.get_user_listings(User);
    assert_eq!(
        listings_by_users,
        array![
            Listing {
                id: 1, details: "TEST_LISTING", owner: User, price: 100, tag: ListingTag::ForSale
            }
        ]
    );

    // Check if NFT was minted
    let minted_coiton_nft_id = erc721.get_user_token_id(User);
    assert!(minted_coiton_nft_id > 0, "NFT_NOT_MINTED");

    // Ensure that the last minted id is the same as the minted coiton nft id
    let last_minted_id = erc721.get_last_minted_id();
    assert_eq!(
        last_minted_id,
        minted_coiton_nft_id,
        "Minted token id is not the same as the last minted id"
    );

    // Ensure that the minted timestamp is the same as the minted coiton nft id
    let minted_timestamp = erc721.get_token_mint_timestamp(minted_coiton_nft_id);
    let current_block_timestamp = get_block_timestamp();
    assert_eq!(
        minted_timestamp,
        current_block_timestamp,
        "Minted timestamp is not the same as the current block timestamp"
    );

    stop_cheat_caller_address(coiton_contract_address);
}

#[test]
fn test_create_listings_event(){
    let coiton_contract_address = _setup_();
    let coiton = ICoitonDispatcher { contract_address: coiton_contract_address };
    let erc721 = IERC721Dispatcher { contract_address: coiton.get_erc721() };
    let mut spy = spy_events();

    let User: ContractAddress = USER();

    // Register user
    start_cheat_caller_address(coiton_contract_address, User);
    let details: ByteArray = "TEST_USERS_ENTITY";
    coiton.register(UserType::Entity, details);
    let is_registered = coiton.get_user(User);
    assert!(is_registered.details == "TEST_USERS_ENTITY", "ALREADY_EXISTS");
    stop_cheat_caller_address(coiton_contract_address);

    //User create listing
    start_cheat_caller_address(coiton_contract_address, User);

    let listing_dettails: ByteArray = "TEST_LISTING";

    coiton.create_listing(100, listing_dettails);

    // Check if the event was emitted
    let expected_event = Event::CreateListing(
        events::CreateListing {
            id: 1,
            owner: User,
            price: 100,
        },
    );
    spy.assert_emitted(@array![(coiton_contract_address, expected_event)]);
    stop_cheat_caller_address(coiton_contract_address);
}
