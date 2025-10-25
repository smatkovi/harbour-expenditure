#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Splitwise OAuth Token Generator
Run this once to get your OAuth tokens for Splitwise API access
"""

import sys

try:
    from requests_oauthlib import OAuth1Session
except ImportError:
    print("ERROR: requests-oauthlib not installed")
    print("Install with: pip3 install requests-oauthlib")
    print("Or on Sailfish: devel-su pkcon install python3-requests-oauthlib")
    sys.exit(1)

def get_oauth_tokens():
    """
    Interactive script to obtain OAuth tokens from Splitwise
    """
    print("=" * 60)
    print("Splitwise OAuth Token Generator")
    print("=" * 60)
    print()
    
    # Step 1: Get consumer credentials
    print("Step 1: Register your application")
    print("-" * 60)
    print("1. Go to: https://secure.splitwise.com/apps")
    print("2. Click 'Register your application'")
    print("3. Fill in:")
    print("   - Application name: Expenditure Sync")
    print("   - Homepage URL: http://localhost")
    print("   - Callback URL: http://localhost/callback")
    print("4. Save and copy your Consumer Key and Secret")
    print()
    
    consumer_key = input("Enter your Consumer Key: ").strip()
    if not consumer_key:
        print("ERROR: Consumer Key is required")
        sys.exit(1)
    
    consumer_secret = input("Enter your Consumer Secret: ").strip()
    if not consumer_secret:
        print("ERROR: Consumer Secret is required")
        sys.exit(1)
    
    print()
    print("Step 2: Authorize application")
    print("-" * 60)
    
    # Get request token
    try:
        oauth = OAuth1Session(consumer_key, client_secret=consumer_secret)
        request_token_url = 'https://secure.splitwise.com/api/v3.0/get_request_token'
        
        print("Fetching request token...")
        fetch_response = oauth.fetch_request_token(request_token_url)
        
        resource_owner_key = fetch_response.get('oauth_token')
        resource_owner_secret = fetch_response.get('oauth_token_secret')
        
        # Get authorization URL
        base_authorization_url = 'https://secure.splitwise.com/authorize'
        authorization_url = oauth.authorization_url(base_authorization_url)
        
        print()
        print("Please authorize the application:")
        print()
        print(authorization_url)
        print()
        print("After authorizing, you will be redirected to:")
        print("http://localhost/callback?oauth_token=...")
        print()
        
        redirect_response = input("Paste the FULL redirect URL here: ").strip()
        
        if not redirect_response or 'oauth_token' not in redirect_response:
            print("ERROR: Invalid redirect URL")
            sys.exit(1)
        
        print()
        print("Step 3: Getting access tokens")
        print("-" * 60)
        
        # Parse authorization response
        oauth = OAuth1Session(consumer_key,
                             client_secret=consumer_secret,
                             resource_owner_key=resource_owner_key,
                             resource_owner_secret=resource_owner_secret)
        
        oauth_response = oauth.parse_authorization_response(redirect_response)
        verifier = oauth_response.get('oauth_verifier')
        
        # Get access token
        access_token_url = 'https://secure.splitwise.com/api/v3.0/get_access_token'
        oauth = OAuth1Session(consumer_key,
                             client_secret=consumer_secret,
                             resource_owner_key=resource_owner_key,
                             resource_owner_secret=resource_owner_secret,
                             verifier=verifier)
        
        print("Fetching access tokens...")
        oauth_tokens = oauth.fetch_access_token(access_token_url)
        
        oauth_token = oauth_tokens.get('oauth_token')
        oauth_token_secret = oauth_tokens.get('oauth_token_secret')
        
        print()
        print("=" * 60)
        print("SUCCESS! Your OAuth tokens:")
        print("=" * 60)
        print()
        print(f"CONSUMER_KEY = \"{consumer_key}\"")
        print(f"CONSUMER_SECRET = \"{consumer_secret}\"")
        print(f"OAUTH_TOKEN = \"{oauth_token}\"")
        print(f"OAUTH_TOKEN_SECRET = \"{oauth_token_secret}\"")
        print()
        
        # Test the tokens
        print("Step 4: Testing connection")
        print("-" * 60)
        
        test_session = OAuth1Session(consumer_key,
                                     client_secret=consumer_secret,
                                     resource_owner_key=oauth_token,
                                     resource_owner_secret=oauth_token_secret)
        
        response = test_session.get('https://secure.splitwise.com/api/v3.0/get_current_user')
        
        if response.status_code == 200:
            user_data = response.json()['user']
            print(f"✓ Successfully connected as: {user_data['first_name']} {user_data['last_name']}")
            print(f"✓ Email: {user_data['email']}")
            
            # Get groups
            response = test_session.get('https://secure.splitwise.com/api/v3.0/get_groups')
            if response.status_code == 200:
                groups = response.json()['groups']
                print()
                print("Your Splitwise groups:")
                print("-" * 60)
                for group in groups:
                    print(f"  Group ID: {group['id']:8} - {group['name']}")
                print()
                print("Note: Use one of these Group IDs in your configuration")
        else:
            print("✗ Connection test failed")
            print(f"Status: {response.status_code}")
            print(f"Response: {response.text}")
        
        print()
        print("=" * 60)
        print("Next steps:")
        print("=" * 60)
        print("1. Copy the credentials above to your splitwise_config.py")
        print("2. Choose a Group ID from the list above")
        print("3. Add the Group ID to splitwise_config.py or SplitwiseSync.qml")
        print()
        
    except Exception as e:
        print(f"ERROR: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == '__main__':
    get_oauth_tokens()
