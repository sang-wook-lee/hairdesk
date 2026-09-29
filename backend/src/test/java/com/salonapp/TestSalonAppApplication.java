package com.salonapp;

import org.springframework.boot.SpringApplication;

public class TestSalonAppApplication {

	public static void main(String[] args) {
		SpringApplication.from(SalonAppApplication::main).with(TestcontainersConfiguration.class).run(args);
	}

}
