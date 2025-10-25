#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Splitwise Backend for Expenditure App
Bidirectional sync between Splitwise and Expenditure
"""

import sqlite3
import os
from datetime import datetime
import re

# Import configuration
try:
    from splitwise_config import CONSUMER_KEY, CONSUMER_SECRET, OAUTH_TOKEN, OAUTH_TOKEN_SECRET, GROUP_ID
except ImportError:
    # Fallback to defaults if config file doesn't exist
    CONSUMER_KEY = ""
    CONSUMER_SECRET = ""
    OAUTH_TOKEN = ""
    OAUTH_TOKEN_SECRET = ""
    GROUP_ID = 0

DB_PATH = os.path.expanduser("~/.local/share/org.tplabs/expenditure/QML/OfflineStorage/Databases/4571a28a53ace9fa74e99ab9f5e19409.sqlite")
SPLITWISE_API_BASE = "https://secure.splitwise.com/api/v3.0"
SYNC_MARKER = "[SW:"

def normalize_beneficiaries(beneficiaries_str):
    """Extract beneficiary names, ignoring all formatting"""
    names = [b.strip().lower() for b in str(beneficiaries_str).split('|||') if b.strip()]
    return tuple(sorted(names))

def get_active_project_id():
    """Get the active project ID"""
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute("SELECT value FROM __local_settings WHERE key = 'activeProjectID_unixtime'")
        result = cursor.fetchone()
        conn.close()
        if result:
            return int(result[0])
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute("SELECT rowid FROM projects LIMIT 1")
        result = cursor.fetchone()
        conn.close()
        return int(result[0]) if result else None
    except:
        return None

def find_user_id(name_to_id, name):
    """Find user ID by name"""
    name_lower = str(name).lower().strip()
    if name_lower in name_to_id:
        return name_to_id[name_lower]
    for stored_name, user_id in name_to_id.items():
        if name_lower in stored_name or stored_name in name_lower:
            return user_id
    return None

def create_expense(session, group_id, description, cost, currency, date, payer_id, beneficiary_ids):
    """Create expense in Splitwise"""
    payer_is_beneficiary = payer_id in beneficiary_ids
    num_beneficiaries = len(beneficiary_ids)
    share_per_person = round(cost / num_beneficiaries, 2)
    total_shares = share_per_person * (num_beneficiaries - 1)
    last_share = round(cost - total_shares, 2)
    
    payload = {
        'group_id': str(group_id),
        'description': description,
        'cost': str(cost),
        'currency_code': currency,
        'date': date,
    }
    
    idx = 0
    payload['users__' + str(idx) + '__user_id'] = str(payer_id)
    payload['users__' + str(idx) + '__paid_share'] = str(cost)
    
    if payer_is_beneficiary:
        payer_index = beneficiary_ids.index(payer_id)
        if payer_index == num_beneficiaries - 1:
            payload['users__' + str(idx) + '__owed_share'] = str(last_share)
        else:
            payload['users__' + str(idx) + '__owed_share'] = str(share_per_person)
    else:
        payload['users__' + str(idx) + '__owed_share'] = '0.00'
    
    idx += 1
    
    for beneficiary_idx, user_id in enumerate(beneficiary_ids):
        if user_id == payer_id:
            continue
        owed_share = last_share if beneficiary_idx == num_beneficiaries - 1 else share_per_person
        payload['users__' + str(idx) + '__user_id'] = str(user_id)
        payload['users__' + str(idx) + '__owed_share'] = str(owed_share)
        payload['users__' + str(idx) + '__paid_share'] = '0.00'
        idx += 1
    
    response = session.post(SPLITWISE_API_BASE + "/create_expense", data=payload)
    response.raise_for_status()
    return response.json()

def sync_project(project_id_or_name, group_id):
    """Bidirectional sync with Splitwise"""
    try:
        # Validate credentials
        if not CONSUMER_KEY or not CONSUMER_SECRET or not OAUTH_TOKEN or not OAUTH_TOKEN_SECRET:
            return {'success': False, 'error': 'Missing Splitwise API credentials. Please configure splitwise_config.py'}
        
        if project_id_or_name is None or isinstance(project_id_or_name, str):
            if project_id_or_name is None:
                project_id = get_active_project_id()
            else:
                conn = sqlite3.connect(DB_PATH)
                cursor = conn.cursor()
                cursor.execute("SELECT rowid FROM projects WHERE name = ?", (project_id_or_name,))
                result = cursor.fetchone()
                conn.close()
                project_id = int(result[0]) if result else None
                if not project_id:
                    return {'success': False, 'error': 'Project not found'}
        else:
            project_id = int(project_id_or_name)
        
        if not project_id or group_id is None:
            return {'success': False, 'error': 'Invalid project or group ID'}
        
        group_id = int(group_id)
        
        from requests_oauthlib import OAuth1Session
        session = OAuth1Session(CONSUMER_KEY, client_secret=CONSUMER_SECRET,
                              resource_owner_key=OAUTH_TOKEN, resource_owner_secret=OAUTH_TOKEN_SECRET)
        
        # Get group members
        response = session.get(f"{SPLITWISE_API_BASE}/get_group/{group_id}")
        response.raise_for_status()
        members = response.json()['group']['members']
        
        id_to_name = {}
        name_to_id = {}
        for m in members:
            full_name = f"{m.get('first_name', '')} {m.get('last_name', '')}".strip()
            id_to_name[m['id']] = full_name
            name_to_id[full_name.lower()] = m['id']
        
        # Get Splitwise expenses
        response = session.get(f"{SPLITWISE_API_BASE}/get_expenses", params={'group_id': group_id, 'limit': 100})
        response.raise_for_status()
        all_expenses = response.json()['expenses']
        splitwise_expenses = [e for e in all_expenses if not (e.get('deleted') or e.get('deleted_at'))]
        
        # Build Splitwise index
        sw_index = {}
        sw_id_map = {}
        for sw_exp in splitwise_expenses:
            sw_id = str(sw_exp['id'])
            desc = sw_exp['description'].lower().strip()
            cost = round(float(sw_exp['cost']), 2)
            date = sw_exp['date'][:10]
            
            sw_beneficiaries = tuple(sorted([id_to_name.get(u['user']['id'], '').lower() 
                                            for u in sw_exp['users'] if float(u['owed_share']) > 0]))
            
            key = (desc, cost, date, sw_beneficiaries)
            sw_index[key] = sw_id
            sw_id_map[sw_id] = sw_exp
        
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        # UPLOAD: Local -> Splitwise
        cursor.execute("SELECT rowid, name, sum, currency, local_time, payer, beneficiaries, info FROM expenses WHERE project = ?", (project_id,))
        local_expenses = cursor.fetchall()
        
        uploaded = 0
        skipped_upload = 0
        
        for exp in local_expenses:
            rowid, name, cost, currency, local_time, payer, beneficiaries_str, info = exp
            
            # Skip if already synced to Splitwise
            if info and SYNC_MARKER in info:
                skipped_upload += 1
                continue
            
            date = local_time[:10]
            desc_key = name.lower().strip()
            cost_key = round(float(cost), 2)
            local_ben_norm = normalize_beneficiaries(beneficiaries_str)
            
            key = (desc_key, cost_key, date, local_ben_norm)
            
            if key in sw_index:
                # Already exists on Splitwise, mark it
                sw_id = sw_index[key]
                new_info = (info or '') + f"{SYNC_MARKER}{sw_id}]"
                cursor.execute("UPDATE expenses SET info = ? WHERE rowid = ?", (new_info, rowid))
                conn.commit()
                skipped_upload += 1
                continue
            
            # Upload to Splitwise
            payer_id = find_user_id(name_to_id, payer)
            if not payer_id:
                continue
            
            beneficiary_names = [b.strip() for b in str(beneficiaries_str).split('|||') if b.strip()]
            beneficiary_ids = [find_user_id(name_to_id, b) for b in beneficiary_names]
            beneficiary_ids = [bid for bid in beneficiary_ids if bid]
            
            if not beneficiary_ids:
                continue
            
            try:
                result = create_expense(session, group_id, name, cost, currency, date, payer_id, beneficiary_ids)
                if 'expenses' in result and len(result['expenses']) > 0:
                    sw_id = str(result['expenses'][0]['id'])
                    new_info = (info or '') + f"{SYNC_MARKER}{sw_id}]"
                    cursor.execute("UPDATE expenses SET info = ? WHERE rowid = ?", (new_info, rowid))
                    conn.commit()
                    uploaded += 1
                    sw_index[key] = sw_id
            except Exception as e:
                print(f"Upload error: {e}")
        
        # Build local index
        cursor.execute("SELECT rowid, name, sum, currency, local_time, payer, beneficiaries, info FROM expenses WHERE project = ?", (project_id,))
        local_expenses = cursor.fetchall()
        
        local_index = {}
        local_sw_ids = set()
        for exp in local_expenses:
            rowid, name, cost, currency, local_time, payer, beneficiaries_str, info = exp
            if info and SYNC_MARKER in info:
                match = re.search(r'\[SW:(\d+)\]', info)
                if match:
                    local_sw_ids.add(match.group(1))
            
            date = local_time[:10]
            key = (name.lower().strip(), round(float(cost), 2), date, normalize_beneficiaries(beneficiaries_str))
            local_index[key] = True
        
        # DOWNLOAD: Splitwise -> Local
        downloaded = 0
        skipped_download = 0
        
        for expense in splitwise_expenses:
            sw_id = str(expense['id'])
            
            if sw_id in local_sw_ids:
                skipped_download += 1
                continue
            
            desc = expense['description']
            cost = round(float(expense['cost']), 2)
            date = expense['date'][:10]
            currency = expense['currency_code']
            
            sw_payer_name = None
            sw_beneficiaries = []
            for user in expense['users']:
                name = id_to_name.get(user['user']['id'], 'Unknown')
                if float(user['paid_share']) > 0:
                    sw_payer_name = name
                if float(user['owed_share']) > 0:
                    sw_beneficiaries.append(name)
            
            key = (desc.lower().strip(), cost, date, tuple(sorted([b.lower() for b in sw_beneficiaries])))
            
            if key in local_index:
                skipped_download += 1
                continue
            
            if not sw_payer_name and sw_beneficiaries:
                sw_payer_name = sw_beneficiaries[0]
            
            beneficiaries_str = " ||| " + " ||| ".join(sw_beneficiaries) + " |||" if sw_beneficiaries else " |||"
            local_time = date + " 12:00:00"
            now = datetime.now().isoformat()
            info_with_marker = f"{SYNC_MARKER}{sw_id}]"
            
            cursor.execute("""
                INSERT INTO expenses 
                (project, name, sum, currency, local_time, local_tz, payer, beneficiaries, utc_time, info, rate, percentage_fees, fixed_fees)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, NULL, NULL)
            """, (project_id, desc, cost, currency, local_time, "CEST", sw_payer_name, beneficiaries_str, now, info_with_marker))
            downloaded += 1
            local_index[key] = True
        
        conn.commit()
        conn.close()
        
        deleted_count = len(all_expenses) - len(splitwise_expenses)
        message = f"↑{uploaded} ↓{downloaded}"
        if skipped_upload or skipped_download:
            message += f" (skip {skipped_upload}↑ {skipped_download}↓)"
        if deleted_count:
            message += f" ✗{deleted_count}"
        
        return {
            'success': True,
            'uploaded': uploaded,
            'downloaded': downloaded,
            'skipped_upload': skipped_upload,
            'skipped_download': skipped_download,
            'deleted': deleted_count,
            'message': message
        }
        
    except Exception as e:
        import traceback
        return {
            'success': False,
            'error': str(e),
            'traceback': traceback.format_exc()
        }
