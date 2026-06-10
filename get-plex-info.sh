#!/bin/bash

# Helper script to get Plex token and library section information
# Run this on your Plex server to gather the information needed for configuration

echo "=== Plex Configuration Helper ==="
echo ""

PLEX_URL="http://localhost:32400"

# Function to find Plex token from Plex preferences
find_plex_token() {
    echo "Searching for Plex token in Plex preferences..."
    echo ""
    
    # Common Plex preference file locations
    PREF_LOCATIONS=(
        "/var/lib/plexmediaserver/Library/Application Support/Plex Media Server/Preferences.xml"
        "$HOME/Library/Application Support/Plex Media Server/Preferences.xml"
        "/config/Library/Application Support/Plex Media Server/Preferences.xml"
    )
    
    for pref_file in "${PREF_LOCATIONS[@]}"; do
        if [ -f "$pref_file" ]; then
            echo "Found Preferences.xml at: $pref_file"
            
            # Extract token from preferences
            TOKEN=$(grep -oP 'PlexOnlineToken="\K[^"]+' "$pref_file" 2>/dev/null)
            
            if [ -n "$TOKEN" ]; then
                echo ""
                echo "✓ Plex Token Found!"
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo "$TOKEN"
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo ""
                return 0
            fi
        fi
    done
    
    echo "✗ Could not automatically find Plex token"
    echo ""
    echo "Manual methods to get your token:"
    echo "1. Visit: https://support.plex.tv/articles/204059436-finding-an-authentication-token-x-plex-token/"
    echo "2. Sign in to Plex Web, play any media, click '...' → 'Get Info' → 'View XML'"
    echo "3. Look for 'X-Plex-Token=' in the URL"
    echo ""
    return 1
}

# Function to get library sections
get_library_sections() {
    local token=$1
    
    if [ -z "$token" ]; then
        echo "Please provide your Plex token to get library sections:"
        read -r token
    fi
    
    echo ""
    echo "Fetching library sections..."
    echo ""
    
    # Get library sections from Plex API
    response=$(curl -s "${PLEX_URL}/library/sections/?X-Plex-Token=${token}")
    
    if [ $? -ne 0 ]; then
        echo "✗ Failed to connect to Plex server at $PLEX_URL"
        return 1
    fi
    
    # Check if response contains error
    if echo "$response" | grep -q "401 Unauthorized"; then
        echo "✗ Authentication failed - invalid token"
        return 1
    fi
    
    echo "✓ Library Sections:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Parse and display sections
    echo "$response" | grep -oP '<Directory[^>]*' | while read -r line; do
        key=$(echo "$line" | grep -oP 'key="\K[^"]+')
        title=$(echo "$line" | grep -oP 'title="\K[^"]+')
        type=$(echo "$line" | grep -oP 'type="\K[^"]+')
        
        if [ -n "$key" ] && [ -n "$title" ]; then
            printf "Section ID: %-3s | Type: %-10s | Title: %s\n" "$key" "$type" "$title"
        fi
    done
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# Function to test library refresh
test_refresh() {
    local token=$1
    local section=$2
    
    if [ -z "$token" ]; then
        echo "Please provide your Plex token:"
        read -r token
    fi
    
    if [ -z "$section" ]; then
        echo "Please provide section ID to test (e.g., 1):"
        read -r section
    fi
    
    echo ""
    echo "Testing library refresh for section $section..."
    
    response=$(curl -s -o /dev/null -w "%{http_code}" "${PLEX_URL}/library/sections/${section}/refresh?X-Plex-Token=${token}")
    
    if [ "$response" = "200" ]; then
        echo "✓ Successfully triggered refresh for section $section (HTTP $response)"
        return 0
    else
        echo "✗ Failed to trigger refresh for section $section (HTTP $response)"
        return 1
    fi
}

# Main script
echo "This script will help you gather the information needed to configure plex-refresh.sh"
echo ""

# Try to find token automatically
if find_plex_token; then
    # Re-extract the token for use
    FOUND_TOKEN=$(grep -oP 'PlexOnlineToken="\K[^"]+' /var/lib/plexmediaserver/Library/Application\\ Support/Plex\\ Media\\ Server/Preferences.xml 2>/dev/null || \
                   grep -oP 'PlexOnlineToken="\K[^"]+' "$HOME/Library/Application Support/Plex Media Server/Preferences.xml" 2>/dev/null || \
                   grep -oP 'PlexOnlineToken="\K[^"]+' /config/Library/Application\\ Support/Plex\\ Media\\ Server/Preferences.xml 2>/dev/null)
    
    # Ask if user wants to use this token
    echo "Use this token? (y/n):"
    read -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        TOKEN="$FOU..."
        get_library_sections "$TOKEN"
        
        echo ""
        echo "Would you like to test a library refresh? (y/n):"
        read -n 1 -r
        echo ""
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            test_refresh "$TOKEN"
        fi
    fi
else
    echo "Would you like to manually enter your token to get library sections? (y/n):"
    read -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        get_library_sections
    fi
fi

echo ""
echo "=== Configuration Summary ==="
echo ""
echo "To configure plex-refresh.sh, edit the config file and set:"
echo ""
echo "PLEX_TOKEN=*** "PLEX_URL=\"$PLEX_URL\""
echo ""
echo "And update the section IDs to match your Plex libraries:"
echo ""
echo "SECTION_MOVIE=\"1\"      # Replace with your Movies section ID"
echo "SECTION_TV_SHOW=\"2\"     # Replace with your TV Shows section ID"
echo "SECTION_DOCUMENTARY=\"3\" # Replace with your Documentary section ID"
echo "SECTION_4KMOVIE=\"4\"     # Replace with your 4K Movies section ID"
echo "SECTION_STANDUP=\"5\"     # Replace with your Standup section ID"
echo ""