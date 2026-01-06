import time
import requests
import json
from web3 import Web3
from datetime import datetime, timedelta

# --- Configuration ---
MINIKUBE_IP = "192.168.49.2"
GATEWAY_PORT = "30090"
BASE_URL = f"http://{MINIKUBE_IP}:{GATEWAY_PORT}"
BLOCKCHAIN_URL = "http://localhost:8545" # Requires kubectl port-forward

# Users (from seed_target_user.py)
HOST_EMAIL = "nitixaj335@roratu.com"
TENANT_EMAIL = "demo_tenant@example.com"
PASSWORD = "Test123@"

# Hardhat Accounts (Pre-funded)
# Account #1 (Host)
HOST_WALLET_ADDR = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
# Account #2 (Tenant)
TENANT_WALLET_ADDR = "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC" 
# Wait, let's use Account #3 for Tenant to avoid conflict with Platform Wallet if it was #2 usually
# Account #3
TENANT_WALLET_ADDR = "0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65"
TENANT_PRIVATE_KEY = "0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a" # PK corresponding to above addr

# Contract Address (from previous deployment/walkthrough)
# Check contracts.json or application.properties. 
# Using the one from my recent deployment log: 0x5FbDB2315678afecb367f032d93F642f64180aa3
CONTRACT_ADDRESS = "0x5FbDB2315678afecb367f032d93F642f64180aa3"

PAY_BOOKING_ABI = [{
    "inputs": [
        {"internalType": "uint256", "name": "bookingId", "type": "uint256"},
        {"internalType": "address", "name": "host", "type": "address"},
        {"internalType": "address", "name": "tenant", "type": "address"},
        {"internalType": "uint256", "name": "rentAmount", "type": "uint256"},
        {"internalType": "uint256", "name": "depositAmount", "type": "uint256"}
    ],
    "name": "createBookingPayment",
    "outputs": [],
    "stateMutability": "payable",
    "type": "function"
}]

def get_token(email, password):
    url = f"{BASE_URL}/api/v1/auth/login"
    try:
        resp = requests.post(url, json={"email": email, "password": password})
        if resp.status_code == 200:
            return resp.json().get("token")
        else:
            print(f"❌ Login Bad Status: {resp.status_code} - {resp.text}")
            return None
    except Exception as e:
        print(f"❌ Login Failed: {e}")
        return None

import base64

def extract_id_from_token(token):
    try:
        # JWT is header.payload.signature
        payload_part = token.split('.')[1]
        # Fix padding
        padding = '=' * (4 - len(payload_part) % 4)
        payload_decoded = base64.urlsafe_b64decode(payload_part + padding).decode('utf-8')
        payload_json = json.loads(payload_decoded)
        return payload_json.get('sub')
    except Exception as e:
        print(f"❌ Failed to decode token: {e}")
        return None

def main():
    print("="*60)
    print(f"🚀 Starting Minikube E2E Verification Script")
    print(f"📡 API Gateway: {BASE_URL}")
    print(f"🔗 Blockchain:  {BLOCKCHAIN_URL}")
    print("="*60)

    # 1. Setup Web3
    w3 = Web3(Web3.HTTPProvider(BLOCKCHAIN_URL))
    if not w3.is_connected():
        print("❌ Blockchain NOT connected. Is port-forward running?")
        print("Run: kubectl port-forward svc/blockchain-service 8545:8545 -n derent")
        exit(1)
    print(f"✅ Blockchain Connected (Block: {w3.eth.block_number})")

    # 2. Login
    print("\n🔐 Authenticating Users...")
    host_token = get_token(HOST_EMAIL, PASSWORD)
    if not host_token: exit(1)
    
    tenant_token = get_token(TENANT_EMAIL, PASSWORD)
    if not tenant_token: exit(1)

    host_id = extract_id_from_token(host_token)
    tenant_id = extract_id_from_token(tenant_token)
    
    print(f"✅ Host Logged In (ID: {host_id})")
    print(f"✅ Tenant Logged In (ID: {tenant_id})")

    host_headers = {"Authorization": f"Bearer {host_token}", "Content-Type": "application/json"}
    tenant_headers = {"Authorization": f"Bearer {tenant_token}", "Content-Type": "application/json"}

    # 3. Update Wallets (Using /me endpoint)
    print("\n👤 Updating User Wallets...")
    
    # Update Tenant Wallet
    resp = requests.put(f"{BASE_URL}/api/v1/users/me", json={"walletAddress": TENANT_WALLET_ADDR}, headers=tenant_headers)
    if resp.status_code == 200:
        print(f"✅ Updated Tenant Wallet to {TENANT_WALLET_ADDR}")
    else:
         print(f"⚠️ Failed to update Tenant Wallet: {resp.status_code}")
    
    # Update Host Wallet
    resp = requests.put(f"{BASE_URL}/api/v1/users/me", json={"walletAddress": HOST_WALLET_ADDR}, headers=host_headers)
    if resp.status_code == 200:
        print(f"✅ Updated Host Wallet to {HOST_WALLET_ADDR}")
    else:
         print(f"⚠️ Failed to update Host Wallet: {resp.status_code}")

    # 4. Get Properties (Find one to book)
    print("\n🏠 Fetching Properties...")
    resp = requests.get(f"{BASE_URL}/api/v1/properties", headers=tenant_headers)
    properties = resp.json()
    if not properties:
        print("❌ No properties found to book.")
        exit(1)
    
    # Find a property NOT owned by tenant (self-booking check)
    target_property = None
    for p in properties:
        if str(p.get("userId")) != str(tenant_id):
            target_property = p
            break
            
    if not target_property:
        print("❌ Could not find a suitable property (Host != Tenant).")
        exit(1)
        
    property_id = target_property.get("id")
    price_per_night = target_property.get("dailyPrice")
    print(f"✅ Selected Property: {target_property.get('title')} (ID: {property_id}, Price: {price_per_night} MAD)")

    # Capture initial bookings to identify the new one later
    print("   Snapshotting existing bookings...")
    resp = requests.get(f"{BASE_URL}/api/bookings?tenantId={tenant_id}", headers=tenant_headers)
    initial_booking_ids = [b['id'] for b in resp.json()] if resp.status_code == 200 else []

    # 5. Create Booking
    print("\n📅 Creating Booking...")
    check_in = (datetime.now() + timedelta(days=60)).strftime("%Y-%m-%d")
    check_out = (datetime.now() + timedelta(days=65)).strftime("%Y-%m-%d")
    
    req_body = {
        "userId": tenant_id,
        "propertyId": property_id,
        "checkInDate": check_in,
        "checkOutDate": check_out,
        "numberOfGuests": 2
    }
    
    resp = requests.post(f"{BASE_URL}/api/bookings/request", json=req_body, headers=tenant_headers)
    if resp.status_code not in [200, 201, 202]:
        print(f"❌ Booking Request Failed: {resp.text}")
        exit(1)
        
    print("   Booking Request Sent. Polling for new ID...")
    
    # Poll for the new booking
    booking_id = None
    for i in range(10):
        time.sleep(2)
        resp = requests.get(f"{BASE_URL}/api/bookings?tenantId={tenant_id}", headers=tenant_headers)
        current_bookings = resp.json()
        
        # Find a booking that is NOT in the initial list and matches property
        new_bookings = [b for b in current_bookings if b['id'] not in initial_booking_ids and b.get('propertyId') == property_id]
        
        if new_bookings:
            booking_id = new_bookings[0]['id']
            print(f"✅ Found New Booking ID: {booking_id}")
            # Update total price from the new booking object
            total_price = new_bookings[0]['totalPrice']
            break
        print(f"   Waiting for booking... (Attempt {i+1})")

    if not booking_id:
        print("❌ Could not find the new booking ID after polling.")
        exit(1)

    matching = [] # Dummy to satisfy any old references if needed, but we used new_bookings logic
    # Removed old logic
    # if matching:
    #     booking_id = matching[-1]['id'] # Latest
    #     print(f"✅ Found Booking ID: {booking_id}")
    #     total_price = matching[-1]['totalPrice']
    # else:
    #     print("❌ Could not create/find booking.")
    #     exit(1)

    # 6. Pay on Blockchain
    print("\n💸 Executing Blockchain Payment...")
    contract = w3.eth.contract(address=CONTRACT_ADDRESS, abi=PAY_BOOKING_ABI)
    
    # MAD to ETH conversion (Hardcoded approx rate for test)
    # WEB3_CONFIG says 29079 MAD = 1 ETH
    rate = 29079.0
    eth_amount = float(total_price) / rate
    wei_amount = w3.to_wei(eth_amount, 'ether')
    
    print(f"   Price: {total_price} MAD ~ {eth_amount:.6f} ETH")
    
    nonce = w3.eth.get_transaction_count(TENANT_WALLET_ADDR)
    
    tx = contract.functions.createBookingPayment(
        int(booking_id),
        HOST_WALLET_ADDR,
        TENANT_WALLET_ADDR,
        wei_amount,
        0
    ).build_transaction({
        'from': TENANT_WALLET_ADDR,
        'value': wei_amount,
        'gas': 2000000,
        'gasPrice': w3.to_wei('1', 'gwei'),
        'nonce': nonce,
        'chainId': 31337
    })
    
    signed_tx = w3.eth.account.sign_transaction(tx, TENANT_PRIVATE_KEY)
    tx_hash = w3.eth.send_raw_transaction(signed_tx.raw_transaction)
    print(f"   Tx Sent: {tx_hash.hex()}")
    
    receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
    if receipt['status'] == 1:
        print("✅ Payment Confirmed on Blockchain")
    else:
        print("❌ Payment Failed on Blockchain")
        exit(1)

    # 7. Verify Status Update
    print("\n🔍 Verifying Backend Status Update...")
    # Payment service listens to events, update might take a few seconds
    # Increased timeout for Minikube environment
    status = "UNKNOWN"
    for i in range(30):
        time.sleep(2)
        resp = requests.get(f"{BASE_URL}/api/bookings/{booking_id}", headers=tenant_headers)
        status = resp.json().get("status")
        # print(f"   Attempt {i+1}: Status = {status}") # Optional verbose
        if status == "CONFIRMED":
            print(f"✅ Booking CONFIRMED by Backend! (after {(i+1)*2}s)")
            break
    
    if status != "CONFIRMED":
        print(f"❌ Error: Booking status stuck at {status} (Check Payment Service logs)")
        exit(1)
    
    print("\n" + "="*60)
    print("✅ TEST PASSED SUCCESSFULLY")
    print("="*60)

if __name__ == "__main__":
    main()
