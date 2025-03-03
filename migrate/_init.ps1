# Set permissions for the scripts
chmod +x ./_list_sc.ps1
chmod +x ./_list_sma.ps1
chmod +x ./_move_sc.ps1
chmod +x ./_move_sma.ps1

ls -la *.ps1
# Run the scripts in order
./_list_sc.ps1
./_list_sma.ps1
