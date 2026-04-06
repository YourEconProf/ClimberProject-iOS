# iOS Development Setup

## Xcode Project Creation

Since this is a native iOS project, you'll need to create an Xcode project. The files in this repo provide the Swift source code structure.

### Steps

1. **Create a new project in Xcode:**
   - File → New → Project
   - Choose "App"
   - Product Name: `ClimberProject`
   - Team ID: (your team or leave blank)
   - Organization ID: `com.climbernation` (or your domain)
   - Interface: SwiftUI
   - Language: Swift

2. **Drag the source files into Xcode:**
   - Copy all `.swift` files from this repo into your Xcode project
   - Ensure they're added to the "ClimberProject" target

3. **Install Dependencies:**
   ```bash
   # Using CocoaPods (if preferred over SPM)
   pod init
   pod install
   ```

   Or add via Xcode:
   - File → Add Packages
   - Enter: `https://github.com/supabase-community/supabase-swift.git`
   - Version: main branch
   - Add to "ClimberProject" target

4. **Configure environment variables:**
   - Create a `.xcconfig` file or add to Info.plist
   - Set `SUPABASE_URL` and `SUPABASE_ANON_KEY`

## Next Steps

- [ ] Implement Supabase authentication in `AuthViewModel`
- [ ] Implement Supabase queries in `SupabaseClient`
- [ ] Build athlete list view
- [ ] Build evaluation form
- [ ] Add offline sync (optional)

## Troubleshooting

**"SUPABASE_URL not found in Info.plist"**
- Add your config values to `Info.plist` or use a `.xcconfig` file
- Or update `Config.swift` to read from `.env` (requires custom build step)

**SwiftUI previews not working**
- Restart Xcode
- Clean build folder (Cmd+Shift+K)
