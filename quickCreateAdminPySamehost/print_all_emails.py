ADMIN_USER = {
    "username": "admin",
    "email": "admin@example.com",
    "password": "admin@admin@aidcec", # Please change this
}
SUPERVISOR_USERS = [
    {
        "username": "supervisor1",
        "email": "supervisor1@example.com",
        "password": "Supervisor1@",
        "role": "supervisor",
    },
    {
        "username": "supervisor2",
        "email": "supervisor2@example.com",
        "password": "Supervisor2@",
        "role": "supervisor",
    },
]
REGULAR_USERS = [
    {
        "username": f"User{i:02d}",
        "email": f"user{i:02d}@aidcec.com",
        "password": f"User{i:02d}@aidcec",
        "role": "enduser",
    } for i in range(1,211)
]

# print emails


ALL_USERS = [ADMIN_USER] + SUPERVISOR_USERS + REGULAR_USERS

[print(user["email"]) for user in ALL_USERS]