use starknet::ContractAddress;
use core::option::OptionTrait;
use core::result::ResultTrait;
use core::traits::{TryInto};
use core::byte_array::{ByteArray};




use snforge_std::{
    declare, start_cheat_caller_address, stop_cheat_caller_address, ContractClassTrait,
    DeclareResultTrait, spy_events, EventSpyAssertionsTrait
};

use starknet::{ get_block_timestamp};


use coiton::mods::interfaces::ierc721::{IERC721Dispatcher, IERC721DispatcherTrait};
use coiton::mods::interfaces::ierc20::{IERC20Dispatcher, IERC20DispatcherTrait};
use coiton::mods::interfaces::icoiton::{ICoitonDispatcher, ICoitonDispatcherTrait};
use coiton::mods::{events};
use coiton::mods::types::{ UserType, Listing, ListingTag};
use coiton::mods::events::{UserEventType, PurchaseRequestType};
use coiton::Coiton::{Event};


const ADMIN: felt252 = 'ADMIN';
const ONE_E18: u256 = 1000000000000000000_u256;


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

fn USER2() -> ContractAddress {
    return 'recipient2'.try_into().unwrap();
}

fn BUYER() -> ContractAddress {
    return 'buyer'.try_into().unwrap();
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
fn test_create_listings_event() {
    let coiton_contract_address = _setup_();
    let coiton = ICoitonDispatcher { contract_address: coiton_contract_address };
   
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
        events::CreateListing { id: 1, owner: User, price: 100, },
    );
    spy.assert_emitted(@array![(coiton_contract_address, expected_event)]);
    stop_cheat_caller_address(coiton_contract_address);
}


#[test]
fn test_create_purchase_request() {
    let coiton_contract_address = _setup_();
    let coiton = ICoitonDispatcher { contract_address: coiton_contract_address };
    let erc20 = IERC20Dispatcher { contract_address: coiton.get_erc20() };

    let User: ContractAddress = USER();
    let Buyer: ContractAddress = BUYER();
    let Owner = coiton.get_owner();

    let mint_amount: u256 = 10000_u256 * ONE_E18;
    erc20.mint(Buyer, mint_amount);

    // Register user
    start_cheat_caller_address(coiton_contract_address, User);
    let details: ByteArray = "TEST_USERS_ENTITY";
    coiton.register(UserType::Entity, details);
    let is_registered = coiton.get_user(User);
    assert!(is_registered.details == "TEST_USERS_ENTITY", "ALREADY_EXISTS");
    stop_cheat_caller_address(coiton_contract_address);

    start_cheat_caller_address(coiton_contract_address, Owner);
    coiton.verify_user(User);

    stop_cheat_caller_address(coiton_contract_address);

    // User create listing
    start_cheat_caller_address(coiton_contract_address, User);
    let details: ByteArray = "TEST_LISTING";
    coiton.create_listing(100, details);
    let listings = coiton.get_listing(1);
    assert!(listings.details == "TEST_LISTING", "NOT_CREATED");
    stop_cheat_caller_address(coiton_contract_address);

    // Create purchase request
    // Corrected: Apply cheatcode to ERC20 contract to impersonate Buyer
    start_cheat_caller_address(erc20.contract_address, Buyer);
    erc20.approve(coiton_contract_address, mint_amount);
    assert!(erc20.allowance(Buyer, coiton_contract_address) == mint_amount, "NOT_APPROVED");
    stop_cheat_caller_address(erc20.contract_address);

    start_cheat_caller_address(coiton_contract_address, Buyer);
    coiton.create_purchase_request(listings.id, Option::Some(100));
    let purchase_requests = coiton.get_listing_purchase_requests(1);
    // assert_eq!(
    //     purchase_requests,
    //     array![
    //         PurchaseRequest {
    //             listing_id: 1,
    //             request_id: 1,
    //             price: 100,
    //             initiator: Buyer,
    //             user: Option::Some(User { id: get_user_id, address: User, user_type:
    //             UserType::Entity, details: "TEST_USERS_ENTITY", verified: true, registered: true
    //             })
    //         }
    //     ]
    // );
    stop_cheat_caller_address(coiton_contract_address);
}


#[test]
#[should_panic(expected: 'INVALID_PARAM')]
fn test_create_purchase_request_with_invalid_param() {
    let coiton_contract_address = _setup_();
    let coiton = ICoitonDispatcher { contract_address: coiton_contract_address };
    let erc20 = IERC20Dispatcher { contract_address: coiton.get_erc20() };

    let User: ContractAddress = USER();
    let Buyer: ContractAddress = BUYER();
    // let address_zero: ContractAddress = 0.try_into().unwrap();

    let mint_amount: u256 = 10000_u256 * ONE_E18;
    erc20.mint(Buyer, mint_amount);

    // Register user
    start_cheat_caller_address(coiton_contract_address, User);
    let details: ByteArray = "TEST_USERS_ENTITY";
    coiton.register(UserType::Entity, details);
    let is_registered = coiton.get_user(User);
    assert!(is_registered.details == "TEST_USERS_ENTITY", "ALREADY_EXISTS");
    stop_cheat_caller_address(coiton_contract_address);

    // User create listing
    start_cheat_caller_address(coiton_contract_address, User);
    let details: ByteArray = "TEST_LISTING";
    coiton.create_listing(100, details);
    let listings = coiton.get_listing(1);
    assert!(listings.details == "TEST_LISTING", "NOT_CREATED");
    stop_cheat_caller_address(coiton_contract_address);

    // Create purchase request
    start_cheat_caller_address(erc20.contract_address, Buyer);
    erc20.approve(coiton_contract_address, mint_amount);
    assert!(erc20.allowance(Buyer, coiton_contract_address) == mint_amount, "NOT_APPROVED");
    stop_cheat_caller_address(erc20.contract_address);

    start_cheat_caller_address(coiton_contract_address, User);
    coiton.create_purchase_request(listings.id, Option::Some(100));
    stop_cheat_caller_address(coiton_contract_address);
}


#[test]
#[should_panic(expected: 'ALREADY_EXIST')]
fn test_create_purchase_request_already_exist() {
    let coiton_contract_address = _setup_();
    let coiton = ICoitonDispatcher { contract_address: coiton_contract_address };
    let erc20 = IERC20Dispatcher { contract_address: coiton.get_erc20() };

    let User: ContractAddress = USER();
    let Buyer: ContractAddress = BUYER();

    let mint_amount: u256 = 10000_u256 * ONE_E18;
    erc20.mint(Buyer, mint_amount);

    // Register user
    start_cheat_caller_address(coiton_contract_address, User);
    let details: ByteArray = "TEST_USERS_ENTITY";
    coiton.register(UserType::Entity, details);
    let is_registered = coiton.get_user(User);
    assert!(is_registered.details == "TEST_USERS_ENTITY", "ALREADY_EXISTS");
    stop_cheat_caller_address(coiton_contract_address);

    // User create listing
    start_cheat_caller_address(coiton_contract_address, User);
    let details: ByteArray = "TEST_LISTING";
    coiton.create_listing(100, details);
    let listings = coiton.get_listing(1);
    assert!(listings.details == "TEST_LISTING", "NOT_CREATED");
    stop_cheat_caller_address(coiton_contract_address);

    // Create purchase request
    // Corrected: Apply cheatcode to ERC20 contract to impersonate Buyer
    start_cheat_caller_address(erc20.contract_address, Buyer);
    erc20.approve(coiton_contract_address, mint_amount);
    assert!(erc20.allowance(Buyer, coiton_contract_address) == mint_amount, "NOT_APPROVED");
    stop_cheat_caller_address(erc20.contract_address);

    start_cheat_caller_address(coiton_contract_address, Buyer);
    coiton.create_purchase_request(listings.id, Option::Some(100));
    stop_cheat_caller_address(coiton_contract_address);

    start_cheat_caller_address(coiton_contract_address, Buyer);
    coiton.create_purchase_request(listings.id, Option::Some(100));
    stop_cheat_caller_address(coiton_contract_address);
}


#[test]
#[should_panic(expected: 'INSUFFICIENT_ALLOWANCE')]
fn test_create_purchase_request_insufficient_allowance() {
    let coiton_contract_address = _setup_();
    let coiton = ICoitonDispatcher { contract_address: coiton_contract_address };
    let erc20 = IERC20Dispatcher { contract_address: coiton.get_erc20() };

    let User: ContractAddress = USER();
    let Buyer: ContractAddress = BUYER();

    let mint_amount: u256 = 10000_u256 * ONE_E18;
    erc20.mint(Buyer, mint_amount);

    // Register user
    start_cheat_caller_address(coiton_contract_address, User);
    let details: ByteArray = "TEST_USERS_ENTITY";
    coiton.register(UserType::Entity, details);
    let is_registered = coiton.get_user(User);
    assert!(is_registered.details == "TEST_USERS_ENTITY", "ALREADY_EXISTS");
    stop_cheat_caller_address(coiton_contract_address);

    // User create listing
    start_cheat_caller_address(coiton_contract_address, User);
    let details: ByteArray = "TEST_LISTING";
    coiton.create_listing(100, details);
    let listings = coiton.get_listing(1);
    assert!(listings.details == "TEST_LISTING", "NOT_CREATED");
    stop_cheat_caller_address(coiton_contract_address);

    start_cheat_caller_address(coiton_contract_address, Buyer);
    coiton.create_purchase_request(listings.id, Option::Some(100));
    stop_cheat_caller_address(coiton_contract_address);

    start_cheat_caller_address(coiton_contract_address, Buyer);
    coiton.create_purchase_request(listings.id, Option::Some(100));
    stop_cheat_caller_address(coiton_contract_address);
}


#[test]
fn test_create_purchase_request_emit_event() {
    let coiton_contract_address = _setup_();
    let coiton = ICoitonDispatcher { contract_address: coiton_contract_address };
    let erc20 = IERC20Dispatcher { contract_address: coiton.get_erc20() };

    let User: ContractAddress = USER();
    let Buyer: ContractAddress = BUYER();
    let Owner = coiton.get_owner();
    let mut spy = spy_events();

    let mint_amount: u256 = 10000_u256 * ONE_E18;
    erc20.mint(Buyer, mint_amount);

    // Register user
    start_cheat_caller_address(coiton_contract_address, User);
    let details: ByteArray = "TEST_USERS_ENTITY";
    coiton.register(UserType::Entity, details);
    let is_registered = coiton.get_user(User);
    assert!(is_registered.details == "TEST_USERS_ENTITY", "ALREADY_EXISTS");
    stop_cheat_caller_address(coiton_contract_address);

    start_cheat_caller_address(coiton_contract_address, Owner);
    coiton.verify_user(User);

    stop_cheat_caller_address(coiton_contract_address);

    // User create listing
    start_cheat_caller_address(coiton_contract_address, User);
    let details: ByteArray = "TEST_LISTING";
    coiton.create_listing(100, details);
    let listings = coiton.get_listing(1);
    assert!(listings.details == "TEST_LISTING", "NOT_CREATED");
    stop_cheat_caller_address(coiton_contract_address);

    // Create purchase request
    // Corrected: Apply cheatcode to ERC20 contract to impersonate Buyer
    start_cheat_caller_address(erc20.contract_address, Buyer);
    erc20.approve(coiton_contract_address, mint_amount);
    assert!(erc20.allowance(Buyer, coiton_contract_address) == mint_amount, "NOT_APPROVED");
    stop_cheat_caller_address(erc20.contract_address);

    start_cheat_caller_address(coiton_contract_address, Buyer);
    coiton.create_purchase_request(listings.id, Option::Some(100));
    let purchase_requests = coiton.get_listing_purchase_requests(1);
    assert!(purchase_requests[0].initiator == @Buyer, "PURCHASE_REQUEST_NOT_CREATED");

    // Check if the event was emitted
    let expected_event = Event::PurchaseRequest(
        events::PurchaseRequest {
            listing_id: 1,
            request_id: 1,
            bid_price: Option::Some(100_u256),
            initiator: Buyer,
            request_type: PurchaseRequestType::Create,
        },
    );
    spy.assert_emitted(@array![(coiton_contract_address, expected_event)]);
    stop_cheat_caller_address(coiton_contract_address);
}


#[test]
fn test_approve_purchase_request() {
    let coiton_contract_address = _setup_();
    let coiton = ICoitonDispatcher { contract_address: coiton_contract_address };
    let erc20 = IERC20Dispatcher { contract_address: coiton.get_erc20() };
    let erc721 = IERC721Dispatcher { contract_address: coiton.get_erc721() };

    let User: ContractAddress = USER();
    let Buyer: ContractAddress = BUYER();
    let Owner = coiton.get_owner();

    // Mint sufficient funds to Buyer (10000 * 1e18)
    let mint_amount: u256 = 10000_u256 * ONE_E18;
    erc20.mint(Buyer, mint_amount);
    assert!(erc20.balance_of(Buyer) == mint_amount, "ERC20_TRANSFER_FAILED");
    let amount: u256 = 2000000000_u256 * ONE_E18;
    erc20.mint(coiton_contract_address, amount);
    assert!(erc20.balance_of(coiton_contract_address) == amount, "ERC20_TRANSFER_FAILED ____");

    let user_mint: u256 = 3000000000000_u256 * ONE_E18;
    erc20.mint(User, user_mint);
    assert!(erc20.balance_of(User) == user_mint, "ERC20_TRANSFER_FAILED");

    // Register user
    start_cheat_caller_address(coiton_contract_address, User);
    let details: ByteArray = "TEST_USERS_ENTITY";
    coiton.register(UserType::Entity, details);
    let is_registered = coiton.get_user(User);
    assert!(is_registered.details == "TEST_USERS_ENTITY", "ALREADY_EXISTS");
    stop_cheat_caller_address(coiton_contract_address);

    // Verify user (admin action)
    start_cheat_caller_address(coiton_contract_address, Owner);
    coiton.verify_user(User);
    stop_cheat_caller_address(coiton_contract_address);

    // Create listing
    start_cheat_caller_address(coiton_contract_address, User);
    let details: ByteArray = "TEST_LISTING";
    coiton.create_listing(100, details);
    let listings = coiton.get_listing(1);
    assert!(listings.details == "TEST_LISTING", "NOT_CREATED");
    stop_cheat_caller_address(coiton_contract_address);

    // Approve ERC20 spending
    start_cheat_caller_address(erc20.contract_address, Buyer);
    erc20.approve(coiton_contract_address, mint_amount);
    assert!(erc20.allowance(Buyer, coiton_contract_address) == mint_amount, "ALLOWANCE_FAILED");
    stop_cheat_caller_address(erc20.contract_address);

    // Create purchase request
    start_cheat_caller_address(coiton_contract_address, Buyer);
    coiton.create_purchase_request(listings.id, Option::Some(100));
    let purchase_requests = coiton.get_listing_purchase_requests(1);
    assert!(purchase_requests[0].initiator == @Buyer, "PURCHASE_REQUEST_NOT_CREATED");
    stop_cheat_caller_address(coiton_contract_address);

    // Approve NFT transfer
    start_cheat_caller_address(erc721.contract_address, User);
    erc721.approve(coiton_contract_address, listings.id);
    assert!(erc721.get_approved(listings.id) == coiton_contract_address, "INSUFFICIENT_ALLOWANCE");
    stop_cheat_caller_address(erc721.contract_address);

    // Execute approval
    start_cheat_caller_address(coiton_contract_address, User);
    coiton.approve_purchase_request(listings.id, 1);
    stop_cheat_caller_address(coiton_contract_address);

    // Verify final state
    let updated_listing = coiton.get_listing(1);
    assert!(updated_listing.tag == ListingTag::Sold, "LISTING_NOT_MARKED_SOLD");
}


#[test]
#[should_panic(expected: 'UNAUTHORIZED')]
fn test_approve_purchase_request_unauthorized() {
    let coiton_contract_address = _setup_();
    let coiton = ICoitonDispatcher { contract_address: coiton_contract_address };
    let erc20 = IERC20Dispatcher { contract_address: coiton.get_erc20() };
    let erc721 = IERC721Dispatcher { contract_address: coiton.get_erc721() };

    let User: ContractAddress = USER();
    let Buyer: ContractAddress = BUYER();
    let Owner = coiton.get_owner();

    // Mint sufficient funds to Buyer (10000 * 1e18)
    let mint_amount: u256 = 10000_u256 * ONE_E18;
    erc20.mint(Buyer, mint_amount);
    assert!(erc20.balance_of(Buyer) == mint_amount, "ERC20_TRANSFER_FAILED");
    let amount: u256 = 2000000000_u256 * ONE_E18;
    erc20.mint(coiton_contract_address, amount);
    assert!(erc20.balance_of(coiton_contract_address) == amount, "ERC20_TRANSFER_FAILED ____");

    let user_mint: u256 = 3000000000000_u256 * ONE_E18;
    erc20.mint(User, user_mint);
    assert!(erc20.balance_of(User) == user_mint, "ERC20_TRANSFER_FAILED");

    // Register user
    start_cheat_caller_address(coiton_contract_address, User);
    let details: ByteArray = "TEST_USERS_ENTITY";
    coiton.register(UserType::Entity, details);
    let is_registered = coiton.get_user(User);
    assert!(is_registered.details == "TEST_USERS_ENTITY", "ALREADY_EXISTS");
    stop_cheat_caller_address(coiton_contract_address);

    // Verify user (admin action)
    start_cheat_caller_address(coiton_contract_address, Owner);
    coiton.verify_user(User);
    stop_cheat_caller_address(coiton_contract_address);

    // Create listing
    start_cheat_caller_address(coiton_contract_address, User);
    let details: ByteArray = "TEST_LISTING";
    coiton.create_listing(100, details);
    let listings = coiton.get_listing(1);
    assert!(listings.details == "TEST_LISTING", "NOT_CREATED");
    stop_cheat_caller_address(coiton_contract_address);

    // Approve ERC20 spending
    start_cheat_caller_address(erc20.contract_address, Buyer);
    erc20.approve(coiton_contract_address, mint_amount);
    assert!(erc20.allowance(Buyer, coiton_contract_address) == mint_amount, "ALLOWANCE_FAILED");
    stop_cheat_caller_address(erc20.contract_address);

    // Create purchase request
    start_cheat_caller_address(coiton_contract_address, Buyer);
    coiton.create_purchase_request(listings.id, Option::Some(100));
    let purchase_requests = coiton.get_listing_purchase_requests(1);
    assert!(purchase_requests[0].initiator == @Buyer, "PURCHASE_REQUEST_NOT_CREATED");
    stop_cheat_caller_address(coiton_contract_address);

    // Approve NFT transfer
    start_cheat_caller_address(erc721.contract_address, User);
    erc721.approve(coiton_contract_address, listings.id);
    assert!(erc721.get_approved(listings.id) == coiton_contract_address, "INSUFFICIENT_ALLOWANCE");
    stop_cheat_caller_address(erc721.contract_address);

    // Execute approval
    start_cheat_caller_address(coiton_contract_address, Buyer);
    coiton.approve_purchase_request(listings.id, 1);
    stop_cheat_caller_address(coiton_contract_address);

    // Verify final state
    let updated_listing = coiton.get_listing(1);
    assert!(updated_listing.tag == ListingTag::Sold, "LISTING_NOT_MARKED_SOLD");
}

#[test]
#[should_panic(expected: 'INSUFFICIENT_ALLOWANCE')]
fn test_approve_purchase_request_insufficient_allowance() {
    let coiton_contract_address = _setup_();
    let coiton = ICoitonDispatcher { contract_address: coiton_contract_address };
    let erc20 = IERC20Dispatcher { contract_address: coiton.get_erc20() };

    let User: ContractAddress = USER();
    let Buyer: ContractAddress = BUYER();
    let Owner = coiton.get_owner();

    // Mint sufficient funds to Buyer (10000 * 1e18)
    let mint_amount: u256 = 10000_u256 * ONE_E18;
    erc20.mint(Buyer, mint_amount);
    assert!(erc20.balance_of(Buyer) == mint_amount, "ERC20_TRANSFER_FAILED");
    let amount: u256 = 2000000000_u256 * ONE_E18;
    erc20.mint(coiton_contract_address, amount);
    assert!(erc20.balance_of(coiton_contract_address) == amount, "ERC20_TRANSFER_FAILED ____");

    let user_mint: u256 = 3000000000000_u256 * ONE_E18;
    erc20.mint(User, user_mint);
    assert!(erc20.balance_of(User) == user_mint, "ERC20_TRANSFER_FAILED");

    // Register user
    start_cheat_caller_address(coiton_contract_address, User);
    let details: ByteArray = "TEST_USERS_ENTITY";
    coiton.register(UserType::Entity, details);
    let is_registered = coiton.get_user(User);
    assert!(is_registered.details == "TEST_USERS_ENTITY", "ALREADY_EXISTS");
    stop_cheat_caller_address(coiton_contract_address);

    // Verify user (admin action)
    start_cheat_caller_address(coiton_contract_address, Owner);
    coiton.verify_user(User);
    stop_cheat_caller_address(coiton_contract_address);

    // Create listing
    start_cheat_caller_address(coiton_contract_address, User);
    let details: ByteArray = "TEST_LISTING";
    coiton.create_listing(100, details);
    let listings = coiton.get_listing(1);
    assert!(listings.details == "TEST_LISTING", "NOT_CREATED");
    stop_cheat_caller_address(coiton_contract_address);

    // Approve ERC20 spending
    start_cheat_caller_address(erc20.contract_address, Buyer);
    erc20.approve(coiton_contract_address, mint_amount);
    assert!(erc20.allowance(Buyer, coiton_contract_address) == mint_amount, "ALLOWANCE_FAILED");
    stop_cheat_caller_address(erc20.contract_address);

    // Create purchase request
    start_cheat_caller_address(coiton_contract_address, Buyer);
    coiton.create_purchase_request(listings.id, Option::Some(100));
    let purchase_requests = coiton.get_listing_purchase_requests(1);
    assert!(purchase_requests[0].initiator == @Buyer, "PURCHASE_REQUEST_NOT_CREATED");
    stop_cheat_caller_address(coiton_contract_address);

    // Execute approval

    start_cheat_caller_address(coiton_contract_address, User);
    coiton.approve_purchase_request(listings.id, 1);
    stop_cheat_caller_address(coiton_contract_address);

    // Verify final state
    let updated_listing = coiton.get_listing(1);
    assert!(updated_listing.tag == ListingTag::Sold, "LISTING_NOT_MARKED_SOLD");
}


#[test]
fn test_approve_purchase_request_emit_event() {
    let coiton_contract_address = _setup_();
    let coiton = ICoitonDispatcher { contract_address: coiton_contract_address };
    let erc20 = IERC20Dispatcher { contract_address: coiton.get_erc20() };
    let erc721 = IERC721Dispatcher { contract_address: coiton.get_erc721() };

    let User: ContractAddress = USER();
    let Buyer: ContractAddress = BUYER();
    let Owner = coiton.get_owner();

    let mut spy = spy_events();

    // Mint sufficient funds to Buyer (10000 * 1e18)
    let mint_amount: u256 = 10000_u256 * ONE_E18;
    erc20.mint(Buyer, mint_amount);
    assert!(erc20.balance_of(Buyer) == mint_amount, "ERC20_TRANSFER_FAILED");
    let amount: u256 = 2000000000_u256 * ONE_E18;
    erc20.mint(coiton_contract_address, amount);
    assert!(erc20.balance_of(coiton_contract_address) == amount, "ERC20_TRANSFER_FAILED ____");

    let user_mint: u256 = 3000000000000_u256 * ONE_E18;
    erc20.mint(User, user_mint);
    assert!(erc20.balance_of(User) == user_mint, "ERC20_TRANSFER_FAILED");

    // Register user
    start_cheat_caller_address(coiton_contract_address, User);
    let details: ByteArray = "TEST_USERS_ENTITY";
    coiton.register(UserType::Entity, details);
    let is_registered = coiton.get_user(User);
    assert!(is_registered.details == "TEST_USERS_ENTITY", "ALREADY_EXISTS");
    stop_cheat_caller_address(coiton_contract_address);

    // Verify user (admin action)
    start_cheat_caller_address(coiton_contract_address, Owner);
    coiton.verify_user(User);
    stop_cheat_caller_address(coiton_contract_address);

    // Create listing
    start_cheat_caller_address(coiton_contract_address, User);
    let details: ByteArray = "TEST_LISTING";
    coiton.create_listing(100, details);
    let listings = coiton.get_listing(1);
    assert!(listings.details == "TEST_LISTING", "NOT_CREATED");
    stop_cheat_caller_address(coiton_contract_address);

    // Approve ERC20 spending
    start_cheat_caller_address(erc20.contract_address, Buyer);
    erc20.approve(coiton_contract_address, mint_amount);
    assert!(erc20.allowance(Buyer, coiton_contract_address) == mint_amount, "ALLOWANCE_FAILED");
    stop_cheat_caller_address(erc20.contract_address);

    // Create purchase request
    start_cheat_caller_address(coiton_contract_address, Buyer);
    coiton.create_purchase_request(listings.id, Option::Some(100));
    let purchase_requests = coiton.get_listing_purchase_requests(1);
    assert!(purchase_requests[0].initiator == @Buyer, "PURCHASE_REQUEST_NOT_CREATED");
    stop_cheat_caller_address(coiton_contract_address);

    // Approve NFT transfer
    start_cheat_caller_address(erc721.contract_address, User);
    erc721.approve(coiton_contract_address, listings.id);
    assert!(erc721.get_approved(listings.id) == coiton_contract_address, "INSUFFICIENT_ALLOWANCE");
    stop_cheat_caller_address(erc721.contract_address);

    // Execute approval
    start_cheat_caller_address(coiton_contract_address, User);
    coiton.approve_purchase_request(listings.id, 1);
    stop_cheat_caller_address(coiton_contract_address);

    // Verify final state
    let updated_listing = coiton.get_listing(1);
    assert!(updated_listing.tag == ListingTag::Sold, "LISTING_NOT_MARKED_SOLD");

    // Check if the event was emitted
    let expected_event = Event::PurchaseRequest(
        events::PurchaseRequest {
            listing_id: 1,
            request_id: 1,
            bid_price: Option::None,
            initiator: User,
            request_type: PurchaseRequestType::Approve,
        },
    );
    spy.assert_emitted(@array![(coiton_contract_address, expected_event)]);
}


#[test]
#[should_panic(expected: 'NOT_FOR_SALE')]
fn test_listings_sold() {
    let coiton_contract_address = _setup_();
    let coiton = ICoitonDispatcher { contract_address: coiton_contract_address };
    let erc20 = IERC20Dispatcher { contract_address: coiton.get_erc20() };
    let erc721 = IERC721Dispatcher { contract_address: coiton.get_erc721() };

    let User: ContractAddress = USER();
    let Buyer: ContractAddress = BUYER();
    let Owner = coiton.get_owner();

    // Mint sufficient funds to Buyer (10000 * 1e18)
    let mint_amount: u256 = 10000_u256 * ONE_E18;
    erc20.mint(Buyer, mint_amount);
    assert!(erc20.balance_of(Buyer) == mint_amount, "ERC20_TRANSFER_FAILED");
    let amount: u256 = 2000000000_u256 * ONE_E18;
    erc20.mint(coiton_contract_address, amount);
    assert!(erc20.balance_of(coiton_contract_address) == amount, "ERC20_TRANSFER_FAILED ____");

    let user_mint: u256 = 3000000000000_u256 * ONE_E18;
    erc20.mint(User, user_mint);
    assert!(erc20.balance_of(User) == user_mint, "ERC20_TRANSFER_FAILED");

    // Register user
    start_cheat_caller_address(coiton_contract_address, User);
    let details: ByteArray = "TEST_USERS_ENTITY";
    coiton.register(UserType::Entity, details);
    let is_registered = coiton.get_user(User);
    assert!(is_registered.details == "TEST_USERS_ENTITY", "ALREADY_EXISTS");
    stop_cheat_caller_address(coiton_contract_address);

    // Verify user (admin action)
    start_cheat_caller_address(coiton_contract_address, Owner);
    coiton.verify_user(User);
    stop_cheat_caller_address(coiton_contract_address);

    // Create listing
    start_cheat_caller_address(coiton_contract_address, User);
    let details: ByteArray = "TEST_LISTING";
    coiton.create_listing(100, details);
    let listings = coiton.get_listing(1);
    assert!(listings.details == "TEST_LISTING", "NOT_CREATED");
    stop_cheat_caller_address(coiton_contract_address);

    // Approve ERC20 spending
    start_cheat_caller_address(erc20.contract_address, Buyer);
    erc20.approve(coiton_contract_address, mint_amount);
    assert!(erc20.allowance(Buyer, coiton_contract_address) == mint_amount, "ALLOWANCE_FAILED");
    stop_cheat_caller_address(erc20.contract_address);

    // Create purchase request
    start_cheat_caller_address(coiton_contract_address, Buyer);
    coiton.create_purchase_request(listings.id, Option::Some(100));
    let purchase_requests = coiton.get_listing_purchase_requests(1);
    assert!(purchase_requests[0].initiator == @Buyer, "PURCHASE_REQUEST_NOT_CREATED");
    stop_cheat_caller_address(coiton_contract_address);

    // Approve NFT transfer
    start_cheat_caller_address(erc721.contract_address, User);
    erc721.approve(coiton_contract_address, listings.id);
    assert!(erc721.get_approved(listings.id) == coiton_contract_address, "INSUFFICIENT_ALLOWANCE");
    stop_cheat_caller_address(erc721.contract_address);

    // Execute approval
    start_cheat_caller_address(coiton_contract_address, User);
    coiton.approve_purchase_request(listings.id, 1);
    stop_cheat_caller_address(coiton_contract_address);

    // Verify final state
    let updated_listing = coiton.get_listing(1);
    assert!(updated_listing.tag == ListingTag::Sold, "LISTING_NOT_MARKED_SOLD");

    start_cheat_caller_address(coiton_contract_address, Buyer);
    coiton.create_purchase_request(listings.id, Option::Some(100));
    let purchase_requests = coiton.get_listing_purchase_requests(1);
    assert!(purchase_requests[0].initiator == @Buyer, "PURCHASE_REQUEST_NOT_CREATED");
    stop_cheat_caller_address(coiton_contract_address);
}


#[test]
#[should_panic(expected: 'PRICE_TOO_LOW')]
fn test_create_purchase_request_price_too_low() {
    let coiton_contract_address = _setup_();
    let coiton = ICoitonDispatcher { contract_address: coiton_contract_address };
    let erc20 = IERC20Dispatcher { contract_address: coiton.get_erc20() };
    let erc721 = IERC721Dispatcher { contract_address: coiton.get_erc721() };

    let User: ContractAddress = USER();
    let Buyer: ContractAddress = BUYER();
    let Owner = coiton.get_owner();

    // Mint sufficient funds to Buyer (10000 * 1e18)
    let mint_amount: u256 = 10000_u256 * ONE_E18;
    erc20.mint(Buyer, mint_amount);
    assert!(erc20.balance_of(Buyer) == mint_amount, "ERC20_TRANSFER_FAILED");
    let amount: u256 = 2000000000_u256 * ONE_E18;
    erc20.mint(coiton_contract_address, amount);
    assert!(erc20.balance_of(coiton_contract_address) == amount, "ERC20_TRANSFER_FAILED ____");

    let user_mint: u256 = 3000000000000_u256 * ONE_E18;
    erc20.mint(User, user_mint);
    assert!(erc20.balance_of(User) == user_mint, "ERC20_TRANSFER_FAILED");

    // Register user
    start_cheat_caller_address(coiton_contract_address, User);
    let details: ByteArray = "TEST_USERS_ENTITY";
    coiton.register(UserType::Entity, details);
    let is_registered = coiton.get_user(User);
    assert!(is_registered.details == "TEST_USERS_ENTITY", "ALREADY_EXISTS");
    stop_cheat_caller_address(coiton_contract_address);

    // Verify user (admin action)
    start_cheat_caller_address(coiton_contract_address, Owner);
    coiton.verify_user(User);
    stop_cheat_caller_address(coiton_contract_address);

    // Create listing
    start_cheat_caller_address(coiton_contract_address, User);
    let details: ByteArray = "TEST_LISTING";
    coiton.create_listing(100, details);
    let listings = coiton.get_listing(1);
    assert!(listings.details == "TEST_LISTING", "NOT_CREATED");
    stop_cheat_caller_address(coiton_contract_address);

    // Approve ERC20 spending
    start_cheat_caller_address(erc20.contract_address, Buyer);
    erc20.approve(coiton_contract_address, mint_amount);
    assert!(erc20.allowance(Buyer, coiton_contract_address) == mint_amount, "ALLOWANCE_FAILED");
    stop_cheat_caller_address(erc20.contract_address);

    // Create purchase request
    start_cheat_caller_address(coiton_contract_address, Buyer);
    coiton.create_purchase_request(listings.id, Option::Some(90));
    let purchase_requests = coiton.get_listing_purchase_requests(1);
    assert!(purchase_requests[0].initiator == @Buyer, "PURCHASE_REQUEST_NOT_CREATED");
    stop_cheat_caller_address(coiton_contract_address);

    // Approve NFT transfer
    start_cheat_caller_address(erc721.contract_address, User);
    erc721.approve(coiton_contract_address, listings.id);
    assert!(erc721.get_approved(listings.id) == coiton_contract_address, "INSUFFICIENT_ALLOWANCE");
    stop_cheat_caller_address(erc721.contract_address);

    // Execute approval
    start_cheat_caller_address(coiton_contract_address, User);
    coiton.approve_purchase_request(listings.id, 1);
    stop_cheat_caller_address(coiton_contract_address);

    // Verify final state
    let updated_listing = coiton.get_listing(1);
    assert!(updated_listing.tag == ListingTag::Sold, "LISTING_NOT_MARKED_SOLD");
}


#[test]
fn test_create_listing_nft_owner(){
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

    //User  1 create listing
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


    // Get listing owner address 
    let listing_owner = erc721.owner_of(1);
    assert_eq!(listing_owner, User);

  stop_cheat_caller_address(coiton_contract_address);

   // User 2 create listings 

   let User2: ContractAddress = USER2();

   //Register User2 
start_cheat_caller_address(coiton_contract_address, User2);
let details2: ByteArray = "TEST_USERS_ENTITY";
coiton.register(UserType::Entity, details2);
let is_registered = coiton.get_user(User2);
assert!(is_registered.details == "TEST_USERS_ENTITY", "ALREADY_EXISTS");
stop_cheat_caller_address(coiton_contract_address);

//User 2 create listing
start_cheat_caller_address(coiton_contract_address, User2);

let listing_dettails2: ByteArray = "TEST_LISTING";
coiton.create_listing(100, listing_dettails2);

// Get listings by user
let listings_by_users2 = coiton.get_user_listings(User2);
assert_eq!(
    listings_by_users2,
    array![
        Listing {
            id: 2, details: "TEST_LISTING", owner: User2, price: 100, tag: ListingTag::ForSale
        }
    ]
);

// Get listing owner address
let listing_owner2 = erc721.owner_of(2);
assert_eq!(listing_owner2, User2);

stop_cheat_caller_address(coiton_contract_address);

// Check if the listing owner is different
assert_ne!(listing_owner,listing_owner2 );



}

