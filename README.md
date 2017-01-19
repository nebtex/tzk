



# Create a master server 

    master=true ConsulHost=consul.example.com bash -c "$(curl -fsSL https://git.io/v1b4Q)"
    
 replace consul.example.com  with the public domain of your master server, or you can use your own consul instalation, but need to provide an acl token. after the installation ned it will print the command for add new nodes
